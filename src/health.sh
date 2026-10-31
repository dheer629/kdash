# Service and storage diagnostics. Embedded into kdash before main; also sourceable
# by fixture tests. All Kubernetes reads use the caller's audited KC array.
# Files live in the caller's private TOOLKIT_DIR. Missing/unreadable sources are
# explicitly unknown. No cluster writes, shell evaluation, or automatic repair.

health__status() {
  local source="$1" state="$2" detail="$3"
  printf '%s\t%s\t%s\n' "$state" "$(date +%s)" "$detail" > "$TOOLKIT_DIR/health-$source.status"
}

health__state() {
  local source="$1" state epoch detail
  if [ -r "$TOOLKIT_DIR/health-$source.status" ]; then
    IFS=$'\t' read -r state epoch detail < "$TOOLKIT_DIR/health-$source.status"
    printf '%s' "${state:-unknown}"
  else printf unknown; fi
}

health__failure() {
  local source="$1" err="$2" state=error detail='read failed; source unknown'
  if grep -qiE 'forbidden|cannot (list|get)|returned error: 403' "$err"; then
    state=forbidden; detail='read denied by RBAC; source unknown'
  elif grep -qiE 'unauthorized|must be logged in|returned error: 401' "$err"; then
    state=auth-error; detail='authentication failed; source unknown'
  elif grep -qiE 'doesn.t have a resource type|could not find the requested resource|not found' "$err"; then
    state=unavailable; detail='API or source unavailable; source unknown'
  elif grep -qiE 'x509|certificate|TLS handshake' "$err"; then
    state=tls-error; detail='TLS verification failed; source unknown'
  elif grep -qiE 'timed out|timeout|deadline exceeded' "$err"; then
    state=timeout; detail='read timed out; source unknown'
  elif grep -qiE 'connection refused|no route|unable to connect|connection reset|no such host' "$err"; then
    state=unreachable; detail='API or metrics endpoint unreachable; source unknown'
  fi
  health__status "$source" "$state" "$detail"
}

health__read() {
  local source="$1" resource="$2" scoped="$3" template="$4"
  local tmp="$TOOLKIT_DIR/health-$source.new" err="$TOOLKIT_DIR/health-$source.err" rc
  if [ "$scoped" = yes ]; then
    if "${KC[@]}" get "$resource" "${SCOPE[@]}" --request-timeout="${KDASH_HEALTH_TIMEOUT:-12s}" -o "go-template=$template" > "$tmp" 2> "$err"; then rc=0; else rc=$?; fi
  else
    if "${KC[@]}" get "$resource" --request-timeout="${KDASH_HEALTH_TIMEOUT:-12s}" -o "go-template=$template" > "$tmp" 2> "$err"; then rc=0; else rc=$?; fi
  fi
  if [ "$rc" = 0 ]; then
    mv -f "$tmp" "$TOOLKIT_DIR/health-$source.raw"
    health__status "$source" ok 'successful API read; empty means no objects in this scope'
  else
    rm -f "$tmp"; : > "$TOOLKIT_DIR/health-$source.raw"
    health__failure "$source" "$err"
  fi
  return 0
}

health__volume_metrics() {
  local url="${PROM_URL:-${KDASH_PROM_URL:-}}" service="${PROM_SVC:-${KDASH_PROM_SVC:-}}"
  local path='' query selection ns_ s_ rc=1
  local out="$TOOLKIT_DIR/health-volume-metrics.raw" err="$TOOLKIT_DIR/health-volume-metrics.err"
  : > "$out"; : > "$TOOLKIT_DIR/health-volume-usage.tsv"; : > "$err"
  # Only configured Prometheus or the existing IO collector's detected source.
  # Do not scan services/nodes or introduce another metrics component.
  if [ -z "$url" ] && [ -z "$service" ]; then
    case "${IO_STATE:-}" in
      prom-url) url="${PROM_URL:-}" ;;
      prom-svc) path="${IO_SRC_PATH:-}" ;;
    esac
  fi
  if [ -n "$service" ]; then
    ns_="${NS:-default}"; s_="$service"
    case "$s_" in */*) ns_="${s_%%/*}"; s_="${s_#*/}" ;; esac
    if [ "${ALL_NS:-0}" = 1 ] && [ "$ns_" = "${NS:-}" ]; then
      health__status volume-metrics unknown 'use namespace/service:port with --prom-svc for all-namespace collection'; return 0
    fi
    path="/api/v1/namespaces/$ns_/services/$s_/proxy"
  fi
  if [ -z "$url" ] && [ -z "$path" ]; then
    health__status volume-metrics unknown 'no configured or existing Prometheus source; measured PVC usage unknown'; return 0
  fi
  # Namespace names cannot contain quotes; percent-encode the fixed selector.
  if [ "${ALL_NS:-0}" = 1 ]; then selection='namespace!=""'; else selection="namespace=\"${NS:-default}\""; fi
  query="{__name__=~\"kubelet_volume_stats_(used|capacity|available)_bytes\",$selection}"
  query="$(printf '%s' "$query" | sed -e 's/%/%25/g' -e 's/{/%7B/g' -e 's/}/%7D/g' -e 's/"/%22/g' -e 's/|/%7C/g' -e 's/=/%3D/g' -e 's/~/%7E/g' -e 's/!/%21/g' -e 's/,/%2C/g' -e 's/(/%28/g' -e 's/)/%29/g')"
  if [ -n "$url" ]; then
    if ! command -v curl >/dev/null 2>&1; then
      health__status volume-metrics unavailable 'configured URL requires optional curl; measured PVC usage unknown'; return 0
    fi
    if curl -fsS --connect-timeout 5 --max-time 12 --globoff "${url%/}/federate?match[]=$query" > "$out" 2> "$err"; then rc=0; else rc=$?; fi
  else
    if "${KC[@]}" get --raw "$path/federate?match[]=$query" --request-timeout="${KDASH_HEALTH_TIMEOUT:-12s}" > "$out" 2> "$err"; then rc=0; else rc=$?; fi
  fi
  if [ "$rc" != 0 ]; then
    : > "$out"; health__failure volume-metrics "$err"; return 0
  fi
  awk -v scope="${NS:-default}" -v all="${ALL_NS:-0}" -v now="$(date +%s)" '
    function label(k, s,   p,r) { p=index("," s, "," k "=\""); if (!p) return ""; r=substr("," s,p+length(k)+3); return substr(r,1,index(r,"\"")-1) }
    /^kubelet_volume_stats_(used|capacity|available)_bytes\{/ {
      b=index($0,"{"); e=index($0,"}"); if (!b || !e) next
      metric=substr($0,1,b-1); labels=substr($0,b+1,e-b-1)
      ns=label("namespace",labels); pvc=label("persistentvolumeclaim",labels)
      if (ns=="" || pvc=="" || (!all && ns!=scope)) next
      rest=substr($0,e+1); sub(/^[ \t]+/,"",rest); split(rest,v,/[ \t]+/)
      if (v[1] !~ /^[0-9]+([.][0-9]+)?([eE][+-]?[0-9]+)?$/) next
      ts=(v[2] ~ /^[0-9]+$/ ? v[2]/1000 : now); origin=(v[2] ~ /^[0-9]+$/ ? "exporter" : "collection")
      k=ns SUBSEP pvc; mk=k SUBSEP metric
      # Duplicate scrape series are never summed; use latest timestamp, max at a tie.
      if (!(mk in seen) || ts>T[mk] || (ts==T[mk] && v[1]+0>V[mk])) { V[mk]=v[1]+0; T[mk]=ts; O[mk]=origin; seen[mk]=1 }
      keys[k]=ns "\t" pvc
    }
    END { for (k in keys) {
      printf "%s",keys[k]
      split("used capacity available",names," ")
      for(i=1;i<=3;i++) { mk=k SUBSEP "kubelet_volume_stats_" names[i] "_bytes"; printf "\t%s\t%s\t%s",(mk in seen ? sprintf("%.0f",V[mk]) : "?"),(mk in seen ? sprintf("%.0f",T[mk]) : "?"),(mk in seen ? O[mk] : "?") }
      printf "\n"
    } }
  ' "$out" > "$TOOLKIT_DIR/health-volume-usage.tsv"
  if [ -s "$TOOLKIT_DIR/health-volume-usage.tsv" ]; then
    health__status volume-metrics ok 'kubelet PVC samples from Prometheus; duplicate scrape series use latest/max, never sum'
  else health__status volume-metrics no-data 'source answered without usable PVC samples in scope; measured usage unknown'; fi
}

health_collect() {
  [ -n "${TOOLKIT_DIR:-}" ] || return 1
  mkdir -p "$TOOLKIT_DIR" || return 1
  health__read services services yes '{{range .items}}{{$o := .}}S|{{.metadata.namespace}}|{{.metadata.name}}|{{.spec.type}}|{{.spec.externalName}}|{{.spec.clusterIP}}|{{range $k,$v := .spec.selector}}{{$k}}={{$v}},{{end}}{{"\n"}}{{range .spec.ports}}T|{{$o.metadata.namespace}}|{{$o.metadata.name}}|{{.name}}|{{.port}}|{{.targetPort}}|{{.protocol}}{{"\n"}}{{end}}{{end}}'
  health__read pods pods yes '{{range .items}}{{$o := .}}P|{{.metadata.namespace}}|{{.metadata.name}}|{{.status.phase}}|{{range .status.conditions}}{{if eq .type "Ready"}}{{.status}}{{end}}{{end}}|{{range $k,$v := .metadata.labels}}{{$k}}={{$v}},{{end}}|{{.status.podIP}}|{{.metadata.deletionTimestamp}}{{"\n"}}{{range .spec.volumes}}{{if .persistentVolumeClaim}}V|{{$o.metadata.namespace}}|{{$o.metadata.name}}|{{.name}}|{{.persistentVolumeClaim.claimName}}{{"\n"}}{{end}}{{end}}{{range .spec.containers}}{{$c := .}}{{range .ports}}C|{{$o.metadata.namespace}}|{{$o.metadata.name}}|{{$c.name}}|{{.name}}|{{.containerPort}}|{{.protocol}}{{"\n"}}{{end}}{{range .volumeMounts}}M|{{$o.metadata.namespace}}|{{$o.metadata.name}}|{{$c.name}}|{{.name}}|{{.mountPath}}|{{.readOnly}}{{"\n"}}{{end}}{{end}}{{range .spec.initContainers}}{{$c := .}}{{range .volumeMounts}}M|{{$o.metadata.namespace}}|{{$o.metadata.name}}|init:{{$c.name}}|{{.name}}|{{.mountPath}}|{{.readOnly}}{{"\n"}}{{end}}{{end}}{{end}}'
  health__read endpoints endpointslices.discovery.k8s.io yes '{{range .items}}{{$o := .}}{{$s := index .metadata.labels "kubernetes.io/service-name"}}E|{{.metadata.namespace}}|{{$s}}|{{.metadata.name}}|{{.addressType}}{{"\n"}}{{range .ports}}B|{{$o.metadata.namespace}}|{{$s}}|{{$o.metadata.name}}|{{.name}}|{{.port}}|{{.protocol}}{{"\n"}}{{end}}{{range .endpoints}}D|{{$o.metadata.namespace}}|{{$s}}|{{$o.metadata.name}}|{{.targetRef.namespace}}|{{.targetRef.name}}|{{.targetRef.kind}}|{{.conditions.ready}}|{{.conditions.serving}}|{{.conditions.terminating}}|{{range .addresses}}{{.}},{{end}}{{"\n"}}{{end}}{{end}}'
  health__read ingresses ingresses.networking.k8s.io yes '{{range .items}}{{$o := .}}{{range .spec.rules}}{{$host := .host}}{{range .http.paths}}{{if .backend.service}}I|{{$o.metadata.namespace}}|{{$o.metadata.name}}|{{$o.spec.ingressClassName}}|{{$host}}|{{.path}}|{{.backend.service.name}}|{{if .backend.service.port.name}}{{.backend.service.port.name}}{{else}}{{.backend.service.port.number}}{{end}}{{"\n"}}{{end}}{{end}}{{end}}{{with .spec.defaultBackend}}{{with .service}}I|{{$o.metadata.namespace}}|{{$o.metadata.name}}|{{$o.spec.ingressClassName}}|*|default|{{.name}}|{{if .port.name}}{{.port.name}}{{else}}{{.port.number}}{{end}}{{"\n"}}{{end}}{{end}}{{end}}'
  health__read pvcs persistentvolumeclaims yes '{{range .items}}{{$o := .}}Q|{{.metadata.namespace}}|{{.metadata.name}}|{{.status.phase}}|{{.spec.volumeName}}|{{.spec.storageClassName}}|{{.spec.resources.requests.storage}}|{{.status.capacity.storage}}|{{range .spec.accessModes}}{{.}},{{end}}|{{.spec.volumeMode}}{{"\n"}}{{range .status.conditions}}F|{{$o.metadata.namespace}}|{{$o.metadata.name}}|{{.type}}|{{.status}}|{{.reason}}{{"\n"}}{{end}}{{end}}'
  health__read pvs persistentvolumes no '{{range .items}}Z|{{.metadata.name}}|{{.status.phase}}|{{.spec.storageClassName}}|{{.spec.capacity.storage}}|{{.spec.persistentVolumeReclaimPolicy}}|{{.spec.claimRef.namespace}}|{{.spec.claimRef.name}}|{{with .spec.csi}}{{.driver}}{{end}}{{"\n"}}{{end}}'
  health__read storageclasses storageclasses.storage.k8s.io no '{{range .items}}K|{{.metadata.name}}|{{.provisioner}}|{{.volumeBindingMode}}|{{.allowVolumeExpansion}}|{{.reclaimPolicy}}{{"\n"}}{{end}}'
  health__volume_metrics
  return 0
}

health__sources() { # source... -> a table of where the data came from and how old it is
  local source state epoch detail now age
  now=$(date +%s)
  {
    printf 'SOURCE\tSTATE*\t>READ\tDETAIL~\n'
    for source in "$@"; do
      state=unknown; epoch=''; detail='not collected'
      if [ -r "$TOOLKIT_DIR/health-$source.status" ]; then
        IFS=$'\t' read -r state epoch detail < "$TOOLKIT_DIR/health-$source.status"
      elif [ -n "${TOOLKIT_PID:-}" ]; then
        state=collecting; detail='first read in progress; values appear when it completes'
      fi
      case "$epoch" in ''|*[!0-9]*) age='-' ;; *) age="$((now - epoch))s ago" ;; esac
      [ "$state" != ok ] || detail='read succeeded'
      printf '%s\t%s\t%s\t%s\n' "$source" "${state:-unknown}" "$age" "${detail:-not collected}"
    done
  } | TK_COUNT=0 tk_table "DATA SOURCES" "" "" source sources
}

health_render_services() {
  local source d="$TOOLKIT_DIR/svc-view"
  tk_title "SERVICES AND BACKENDS" "observed configuration and readiness - reachability is not tested"
  health__sources services pods endpoints ingresses
  for source in services pods endpoints ingresses; do
    [ -f "$TOOLKIT_DIR/health-$source.raw" ] || : > "$TOOLKIT_DIR/health-$source.raw"
  done
  mkdir -p "$d"
  LC_ALL=C awk -F'|' -v sf="$TOOLKIT_DIR/health-services.raw" -v pf="$TOOLKIT_DIR/health-pods.raw" \
    -v ef="$TOOLKIT_DIR/health-endpoints.raw" -v inf="$TOOLKIT_DIR/health-ingresses.raw" \
    -v ss="$(health__state services)" -v ps="$(health__state pods)" \
    -v es="$(health__state endpoints)" -v ins="$(health__state ingresses)" -v scope="${NS:-}" -v all="${ALL_NS:-0}" \
    -v arw="$([ "${BARCHR:-unicode}" = ascii ] && printf '%s' '->' || printf '\342\206\222')" -v of="$d/svc.tsv" -v bf="$d/backends.tsv" -v ff="$d/findings.tsv" -v rf="$d/routes.tsv" '
    function clean(s) { return (s=="<no value>" || s=="<nil>" || s=="null") ? "" : s }
    function matches(sel, labels,   a,n,i) {
      n=split(sel,a,","); for(i=1;i<=n;i++) if(a[i]!="" && !index("," labels,"," a[i] ",")) return 0
      return 1
    }
    function proto(s) { return s=="" ? "TCP" : s }
    function nocomma(s) { sub(/,$/,"",s); return s }
    function nm(ns, n) { return (all=="1" || ns!=scope) ? ns "/" n : n }
    function eps(k) { if(es!="ok") return "unknown"; if(EC[k]==0) return "none"
      return (ER[k]+0) "/" (ER[k]+EB[k]+EU[k]) " ready" (EU[k]+0 ? " (" EU[k] " unknown)" : "") }
    function find(sv, k, f, t) { printf "%s\t%s\t%s\n", sv, k, f >> ff; if (sv ~ /CRIT/) NCRIT++ }
    FILENAME==sf && $1=="S" { k=$2 SUBSEP $3; if(!(k in SN)) SK[++NS]=k; SN[k]=nm($2,$3); ST[k]=clean($4); EXT[k]=clean($5); IP[k]=clean($6); SEL[k]=nocomma(clean($7)); next }
    FILENAME==sf && $1=="T" { k=$2 SUBSEP $3; n=++NT[k]; TN[k,n]=clean($4); TP[k,n]=clean($5); TT[k,n]=clean($6); PT[k,n]=proto(clean($7)); next }
    FILENAME==pf && $1=="P" { k=$2 SUBSEP $3; PK[++NP]=k; PN[k]=nm($2,$3); PNS[k]=$2; READY[k]=$5; LABELS[k]=$6; DEL[k]=clean($8); next }
    FILENAME==pf && $1=="C" && clean($5)!="" { PORT[$2 SUBSEP $3 SUBSEP $5 SUBSEP proto(clean($7))]=1; next }
    FILENAME==ef && $1=="E" { k=$2 SUBSEP $3; EC[k]++; next }
    FILENAME==ef && $1=="D" {
      k=$2 SUBSEP $3; if($8=="true") ER[k]++; else if($8=="false") EB[k]++; else EU[k]++
      next
    }
    FILENAME==inf && $1=="I" { IR[++NI]=$0; next }
    END {
      printf "" > ff
      for(si=1;si<=NS;si++) {
        k=SK[si]; split(k,z,SUBSEP)
        if(SEL[k]!="" && ST[k]!="ExternalName" && ps=="ok") for(pi=1;pi<=NP;pi++) {
          p=PK[pi]; if(PNS[p]!=z[1] || !matches(SEL[k],LABELS[p])) continue
          SELECTED[k]++; if(READY[p]=="True" && DEL[p]=="") { PR[k]++; if(PR[k]<=3) PLIST[k]=PLIST[k] (PLIST[k]=="" ? "" : ", ") PN[p] }
          for(ti=1;ti<=NT[k];ti++) if(TT[k,ti]!="" && TT[k,ti]!~/^[0-9]+$/ && !((p SUBSEP TT[k,ti] SUBSEP PT[k,ti]) in PORT)) MISSING[k,ti]++
        }
      }
      # services
      print "SERVICE\tSTATUS*\tTYPE\t>SELECTED\t>READY\tENDPOINTS\tCLUSTER-IP~\tPORTS (name:port"arw"target)" > of
      print "SERVICE\tREADY BACKEND PODS\tSELECTOR~" > bf
      for(si=1;si<=NS;si++) {
        k=SK[si]; selected=(ps=="ok" && SEL[k]!="" && ST[k]!="ExternalName")
        ports=""
        for(ti=1;ti<=NT[k];ti++) { t=TT[k,ti]; pp=(TN[k,ti]!="" ? TN[k,ti] ":" : "") TP[k,ti] (t!="" && t!=TP[k,ti] ? arw t : "") (PT[k,ti]!="TCP" ? "/" PT[k,ti] : "")
          ports=ports (ports=="" ? "" : ", ") pp }
        type=ST[k]; if(IP[k]=="None") type="Headless"; cip=(IP[k]=="" || IP[k]=="None" ? "-" : IP[k])
        st="OK"
        if(ss!="ok") st="unknown"
        else if(ST[k]=="ExternalName") { st="EXTERNAL"; cip=arw " " EXT[k] }
        else if(SEL[k]=="") { st=(es=="ok" && ER[k]+0>0) ? "OK" : "SELECTORLESS"; find("{d}INFO", SN[k], "no selector: backends are managed manually (EndpointSlices " eps(k) ")") }
        else if(ps!="ok") st="unknown"
        else if(SELECTED[k]+0==0) { st="NO MATCH"; find("{r}CRITICAL", SN[k], "selector " SEL[k] " matches no pod in this scope") }
        else if(PR[k]+0==0) { st="NOT READY"; find("{r}CRITICAL", SN[k], SELECTED[k] " selected pod(s), none Ready and serving") }
        for(ti=1;ti<=NT[k];ti++) if(selected && MISSING[k,ti]>0) { if(st=="OK") st="PORT MISSING"
          find("{y}WARNING", SN[k], "named targetPort " TT[k,ti] "/" PT[k,ti] " is not declared on " MISSING[k,ti] " of " SELECTED[k] " selected pod(s)") }
        if(es=="ok" && ST[k]!="ExternalName" && SEL[k]!="" && EC[k]==0) { if(st=="OK") st="NO ENDPOINTS"; find("{y}WARNING", SN[k], "no EndpointSlice exists for this Service") }
        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", SN[k], st, type, (selected ? SELECTED[k]+0 : "-"), (selected ? PR[k]+0 : "-"), (ST[k]=="ExternalName" ? "-" : eps(k)), cip, (ports=="" ? "-" : ports) > of
        if(SEL[k]!="" && ST[k]!="ExternalName") printf "%s\t%s\t%s\n", SN[k], (ps!="ok" ? "unknown" : PR[k]+0==0 ? "{r}none ready" : PLIST[k] (PR[k]>3 ? "  (+" (PR[k]-3) " more)" : "")), SEL[k] > bf
      }
      # ingress routes
      print "INGRESS\tSTATUS*\t>READY PODS\tCLASS~\tHOST / PATH\tBACKEND SERVICE" > rf
      if(ins=="ok") for(i=1;i<=NI;i++) {
        split(IR[i],r,"|"); k=r[2] SUBSEP r[7]; host=clean(r[5]); if(host=="") host="*"
        st="OK"; rp="-"
        if(ss!="ok") st="unknown"
        else if(!(k in SN)) { st="SERVICE MISSING"; find("{r}CRITICAL", nm(r[2],r[3]), "backend Service " r[7] " does not exist") }
        else {
          found=0; for(j=1;j<=NT[k];j++) if(r[8]==TN[k,j] || r[8]==TP[k,j]) found=1
          if(!found) { st="PORT MISMATCH"; find("{r}CRITICAL", nm(r[2],r[3]), "backend port " r[8] " is not a port of Service " r[7]) }
          if(ST[k]=="ExternalName") rp="external"
          else { rp=(ps=="ok" && SEL[k]!="" ? PR[k]+0 : "-"); if(st=="OK" && es=="ok" && ER[k]+0==0) st="NO READY ENDPOINTS" }
        }
        printf "%s\t%s\t%s\t%s\t%s\t%s\n", nm(r[2],r[3]), st, rp, clean(r[4]), host clean(r[6]), r[7] ":" r[8] > rf
      }
    }
  ' "$TOOLKIT_DIR/health-services.raw" "$TOOLKIT_DIR/health-pods.raw" "$TOOLKIT_DIR/health-endpoints.raw" "$TOOLKIT_DIR/health-ingresses.raw"
  [ -s "$d/svc.tsv" ] || printf 'SERVICE\n' > "$d/svc.tsv"
  tk_table "SERVICES" "$([ "$(health__state services)" = ok ] || printf 'source %s' "$(health__state services)")" \
    "no Services in this scope$([ "$(health__state services)" = ok ] || printf ' (source %s)' "$(health__state services)")" service services < "$d/svc.tsv"
  { printf 'SEVERITY*\tOBJECT\tFINDING\n'; tk_by_severity < "$d/findings.tsv"; } |
    tk_table "FINDINGS" "critical first" "nothing wrong found in the collected Services and routes" finding findings
  [ ! -s "$d/backends.tsv" ] || tk_table "BACKENDS" "selector and the Ready pods it selects (first 3)" "no selector-based Services" service services < "$d/backends.tsv"
  if [ "$(health__state ingresses)" = ok ]; then
    tk_table "INGRESS ROUTES" "service-backed rules" "no service-backed Ingress routes in this scope" route routes < "$d/routes.tsv"
  else
    printf 'INGRESS\n' | tk_table "INGRESS ROUTES" "" "unknown - ingresses source $(health__state ingresses)"
  fi
  printf '\n'
  tk_note "Readiness is what the API reports. DNS, ingress controllers, NetworkPolicy, routing, TLS and application responses are not tested."
  rm -rf "$d"
}

health__storage_events() {
  local file=''
  if [ -r "$TOOLKIT_DIR/events.tsv" ]; then file="$TOOLKIT_DIR/events.tsv"
  elif [ -n "${MODEL:-}" ] && [ -r "$MODEL/events.tsv" ]; then file="$MODEL/events.tsv"; fi
  if [ -z "$file" ]; then
    printf 'EVENT\n' | tk_table "STORAGE EVENTS" "" "event data unavailable in this snapshot - see the Events view (E)"
    return 0
  fi
  # events.tsv: NS KIND NAME UID TYPE REASON COUNT FIRST LAST MESSAGE
  LC_ALL=C awk -F'\t' -v now="$(date +%s)" "$TK_TIME_AWK"'
    BEGIN { NOW = now; print "LAST SEEN\tTYPE*\tOBJECT\tREASON\t>COUNT\tMESSAGE" }
    NR == 1 && $1 == "NS" { next }
    tolower($2 " " $6 " " $10) ~ /failedmount|failedattach|failedbinding|failedprovision|provisioningfailed|volume|persistentvolumeclaim|storageclass|claim|waitforfirstconsumer|resiz/ {
      if (++n <= 15) printf "%s\t%s\t%s\t%s\t%s\t%s\n", ago($9), $5, $2 "/" $3, $6, $7, $10 }
  ' "$file" | tk_table "STORAGE EVENTS" "newest first, up to 15" "no storage-related events in the collected window" event events
}

health_render_storage() {
  local source d="$TOOLKIT_DIR/sto-view"
  tk_title "PERSISTENT STORAGE" "claims, volumes and classes - capacity is allocation; usage only from kubelet volume samples"
  health__sources pvcs pods pvs storageclasses volume-metrics
  for source in pvcs pods pvs storageclasses; do
    [ -f "$TOOLKIT_DIR/health-$source.raw" ] || : > "$TOOLKIT_DIR/health-$source.raw"
  done
  [ -f "$TOOLKIT_DIR/health-volume-usage.tsv" ] || : > "$TOOLKIT_DIR/health-volume-usage.tsv"
  mkdir -p "$d"
  LC_ALL=C awk -F'|' -v qf="$TOOLKIT_DIR/health-pvcs.raw" -v pf="$TOOLKIT_DIR/health-pods.raw" \
    -v vf="$TOOLKIT_DIR/health-pvs.raw" -v cf="$TOOLKIT_DIR/health-storageclasses.raw" \
    -v uf="$TOOLKIT_DIR/health-volume-usage.tsv" -v qs="$(health__state pvcs)" \
    -v ps="$(health__state pods)" -v vs="$(health__state pvs)" \
    -v cs="$(health__state storageclasses)" -v us="$(health__state volume-metrics)" -v now="$(date +%s)" \
    -v scope="${NS:-}" -v all="${ALL_NS:-0}" \
    -v cf_out="$d/claims.tsv" -v mf="$d/mounts.tsv" -v vf_out="$d/volumes.tsv" -v kf="$d/classes.tsv" -v ff="$d/findings.tsv" '
    function clean(s) { return (s=="<no value>" || s=="<nil>" || s=="null") ? "" : s }
    function known(s) { return clean(s)=="" ? "-" : s }
    function nocomma(s) { sub(/,$/,"",s); return s }
    function nm(ns, n) { return (all=="1" || ns!=scope) ? ns "/" n : n }
    function acc(s) { gsub(/ReadWriteOncePod/,"RWOP",s); gsub(/ReadWriteOnce/,"RWO",s); gsub(/ReadWriteMany/,"RWX",s); gsub(/ReadOnlyMany/,"ROX",s); gsub(/,/," ",s); return s }
    function bytes(s,   n,i,a) {
      if(s=="?" || s=="") return "-"; n=s+0; split("B KiB MiB GiB TiB PiB",a," "); i=1
      while(n>=1024 && i<6) { n/=1024; i++ } return sprintf("%.1f%s",n,a[i])
    }
    function find(sv, k, f) { printf "%s\t%s\t%s\n", sv, k, f >> ff }
    FILENAME==qf && $1=="Q" { k=$2 SUBSEP $3; QK[++NQ]=k; QN[k]=nm($2,$3); QPH[k]=clean($4); QPV[k]=clean($5); QC[k]=clean($6); QR[k]=clean($7); QCAP[k]=clean($8); QA[k]=nocomma(clean($9)); QM[k]=clean($10); next }
    FILENAME==qf && $1=="F" && $5=="True" { k=$2 SUBSEP $3; COND[k]=COND[k] (COND[k]=="" ? "" : ", ") $4 (clean($6)!="" ? " (" clean($6) ")" : ""); next }
    FILENAME==pf && $1=="P" { k=$2 SUBSEP $3; PP[k]=$4 ($5=="True" ? "" : $5=="False" ? ", not ready" : ""); next }
    FILENAME==pf && $1=="V" { p=$2 SUBSEP $3; k=$2 SUBSEP $5; VCLAIM[p,$4]=k; REF[k,p]=1; next }
    FILENAME==pf && $1=="M" { p=$2 SUBSEP $3; MK[++NM]=p SUBSEP $5; MC[NM]=$4; MP[NM]=$6; MRO[NM]=$7; next }
    FILENAME==vf && $1=="Z" { PV[$2]=1; VK[++NV]=$2; VPH[$2]=clean($3); VC[$2]=clean($4); VCAP[$2]=clean($5); VR[$2]=clean($6); VCL[$2]=clean($7) "/" clean($8); VCLNS[$2]=clean($7); DRIVER[$2]=clean($9); next }
    FILENAME==cf && $1=="K" { SC[$2]=1; SCK[++NSC]=$2; PROV[$2]=clean($3); BIND[$2]=clean($4); EXPAND[$2]=clean($5); RECLAIM[$2]=clean($6); next }
    FILENAME==uf {
      split($0,u,"\t"); k=u[1] SUBSEP u[2]; USED[k]=u[3]; UT[k]=u[4]; CAP[k]=u[6]; CT[k]=u[7]; AVAIL[k]=u[9]; next
    }
    END {
      printf "" > ff
      print "CLAIM\tSTATUS*\t>REQUEST\t>CAPACITY\t>USED\t>USE%\tACCESS\tCLASS\tPODS\tVOLUME~" > cf_out
      print "CLAIM\tPOD\tPOD STATUS*\tCONTAINER\tMOUNT PATH\tMODE" > mf
      if(qs=="ok") for(i=1;i<=NQ;i++) {
        k=QK[i]; v=QPV[k]; c=QC[k]; split(k,kk,SUBSEP)
        pods=""; refs=0
        if(ps=="ok") for(r in REF) { split(r,a,SUBSEP); if(a[1] SUBSEP a[2]!=k) continue; refs++; if(refs<=2) pods=pods (pods=="" ? "" : ", ") nm(a[3],a[4]) }
        if(refs>2) pods=pods " +" (refs-2)
        if(ps!="ok") pods="unknown"; else if(refs==0) pods="{d}none"
        used="-"; pct="-"
        if(us=="ok" && (k in USED)) { used=bytes(USED[k])
          skew=UT[k]-CT[k]; if(skew<0) skew=-skew
          if(USED[k]!="?" && CAP[k]!="?" && CAP[k]+0>0 && skew<=300) { p=100*USED[k]/CAP[k]; pct=(p>=90 ? "{r}" : p>=80 ? "{y}" : "") sprintf("%.0f%%",p)
            if(p>=90) find("{r}CRITICAL", QN[k], sprintf("volume %.0f%% full (%s of %s)", p, bytes(USED[k]), bytes(CAP[k])))
            else if(p>=80) find("{y}WARNING", QN[k], sprintf("volume %.0f%% full (%s of %s)", p, bytes(USED[k]), bytes(CAP[k]))) } }
        st=known(QPH[k]); if(COND[k]!="") st=st " (" COND[k] ")"
        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", QN[k], st, known(QR[k]), known(QCAP[k]), used, pct, acc(known(QA[k])) (QM[k]=="Block" ? " block" : ""), (c!="" ? c : "-"), pods, (v!="" ? v : "{y}unbound") > cf_out
        if(COND[k]!="") find("{y}WARNING", QN[k], "condition " COND[k])
        if(QPH[k]=="Pending") find((c in SC && BIND[c]=="WaitForFirstConsumer") ? "{y}WARNING" : "{r}CRITICAL", QN[k], "claim is Pending" ((c in SC && BIND[c]=="WaitForFirstConsumer") ? " - class " c " binds only when a consuming pod is scheduled" : " - not bound to a volume"))
        if(QPH[k]=="Lost") find("{r}CRITICAL", QN[k], "claim is Lost - its volume no longer exists")
        if(v!="" && vs=="ok" && !(v in PV)) find("{r}CRITICAL", QN[k], "bound volume " v " is missing from the volume list")
        if(v!="" && vs=="ok" && (v in PV) && VCL[v]!="/" && VCL[v]!=kk[1] "/" kk[2]) find("{r}CRITICAL", QN[k], "volume " v " claimRef points to " VCL[v])
        if(c!="" && cs=="ok" && !(c in SC)) find("{y}WARNING", QN[k], "storage class " c " does not exist")
        if(ps=="ok" && refs==0) find("{d}INFO", QN[k], "no pod in this scope references the claim")
        if(c!="") USEDC[c]=1; if(v!="") MINE[v]=1
      }
      if(ps=="ok") for(m=1;m<=NM;m++) if(MK[m] in VCLAIM) {
        k=VCLAIM[MK[m]]; split(MK[m],a,SUBSEP); split(k,kk,SUBSEP)
        printf "%s\t%s\t%s\t%s\t%s\t%s\n", nm(kk[1],kk[2]), nm(a[1],a[2]), known(PP[a[1] SUBSEP a[2]]), MC[m], MP[m], (MRO[m]=="true" ? "read-only" : "read-write") > mf
      }
      if(ps=="ok" && qs=="ok") for(r in REF) { split(r,a,SUBSEP); k=a[1] SUBSEP a[2]
        if(!(k in QN)) find("{r}CRITICAL", nm(a[3],a[4]), "pod refers to claim " a[2] ", which does not exist") }
      print "VOLUME\tSTATUS*\t>CAPACITY\tRECLAIM\tCLASS\tCLAIM\tDRIVER~" > vf_out
      if(vs=="ok") for(i=1;i<=NV;i++) { v=VK[i]; if(!(v in MINE) && !(all=="1") && VCLNS[v]!=scope) continue
        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n", v, known(VPH[v]), known(VCAP[v]), known(VR[v]), known(VC[v]), (VCL[v]=="/" ? "-" : VCL[v]), known(DRIVER[v]) > vf_out
        if(VPH[v]=="Released") find("{y}WARNING", v, "volume is Released: its claim was deleted and the data is retained") }
      print "CLASS\tPROVISIONER\tBINDING\tEXPANSION\tRECLAIM\tUSED HERE" > kf
      if(cs=="ok") for(i=1;i<=NSC;i++) { c=SCK[i]
        printf "%s\t%s\t%s\t%s\t%s\t%s\n", c, known(PROV[c]), known(BIND[c]), (EXPAND[c]=="true" ? "allowed" : "{d}no"), known(RECLAIM[c]), (c in USEDC ? "{g}yes" : "{d}no") > kf }
    }
  ' "$TOOLKIT_DIR/health-pvcs.raw" "$TOOLKIT_DIR/health-pods.raw" "$TOOLKIT_DIR/health-pvs.raw" "$TOOLKIT_DIR/health-storageclasses.raw" "$TOOLKIT_DIR/health-volume-usage.tsv"
  local q; q="$(health__state pvcs)"
  tk_table "PERSISTENT VOLUME CLAIMS" "$([ "$(health__state volume-metrics)" = ok ] || printf 'USED / USE%% need kubelet volume samples (Prometheus) - none here')" \
    "$([ "$q" = ok ] && printf 'no claims in this scope' || printf 'unknown - pvcs source %s' "$q")" claim claims < "$d/claims.tsv"
  { printf 'SEVERITY*\tOBJECT\tFINDING\n'; tk_by_severity < "$d/findings.tsv"; } |
    tk_table "FINDINGS" "critical first" "nothing wrong found in the collected claims and volumes" finding findings
  tk_table "MOUNTS" "declared in pod specs - a declaration does not prove the mount succeeded" \
    "$([ "$(health__state pods)" = ok ] && printf 'no pod mounts a claim in this scope' || printf 'unknown - pods source %s' "$(health__state pods)")" mount mounts < "$d/mounts.tsv"
  tk_table "PERSISTENT VOLUMES" "bound to the claims above" \
    "$([ "$(health__state pvs)" = ok ] && printf 'no volumes' || printf 'unknown - pvs source %s (cluster-scoped, often not readable)' "$(health__state pvs)")" volume volumes < "$d/volumes.tsv"
  tk_table "STORAGE CLASSES" "" \
    "$([ "$(health__state storageclasses)" = ok ] && printf 'no storage classes' || printf 'unknown - storageclasses source %s' "$(health__state storageclasses)")" class classes < "$d/classes.tsv"
  health__storage_events
  printf '\n'
  tk_note "Allocation (request / capacity) and measured filesystem usage can differ; a missing sample never means zero usage."
  rm -rf "$d"
}
