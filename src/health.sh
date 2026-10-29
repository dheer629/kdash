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

health__sources() {
  local source state epoch detail now stamp
  now=$(date +%s)
  for source in "$@"; do
    state=unknown; epoch=''; detail='not collected'
    if [ -r "$TOOLKIT_DIR/health-$source.status" ]; then
      IFS=$'\t' read -r state epoch detail < "$TOOLKIT_DIR/health-$source.status"
    fi
    case "$epoch" in ''|*[!0-9]*) stamp='time unknown' ;;
      *) stamp="$(date -d "@$epoch" '+%Y-%m-%d %H:%M:%S %z' 2>/dev/null || printf '%s' "$epoch") ($((now-epoch))s ago)" ;;
    esac
    printf '  %s: %s; %s; %s\n' "$source" "${state:-unknown}" "$stamp" "${detail:-not collected}"
  done
}

health_render_services() {
  printf 'SERVICES AND BACKENDS\n'
  printf 'Observed Kubernetes configuration and readiness; this does not test end-to-end reachability.\n'
  health__sources services pods endpoints ingresses
  local source
  for source in services pods endpoints ingresses; do
    [ -f "$TOOLKIT_DIR/health-$source.raw" ] || : > "$TOOLKIT_DIR/health-$source.raw"
  done
  awk -F'|' -v sf="$TOOLKIT_DIR/health-services.raw" -v pf="$TOOLKIT_DIR/health-pods.raw" \
    -v ef="$TOOLKIT_DIR/health-endpoints.raw" -v inf="$TOOLKIT_DIR/health-ingresses.raw" \
    -v ss="$(health__state services)" -v ps="$(health__state pods)" \
    -v es="$(health__state endpoints)" -v ins="$(health__state ingresses)" '
    function clean(s) { return (s=="<no value>" || s=="<nil>" || s=="null") ? "" : s }
    function matches(sel, labels,   a,n,i) {
      n=split(sel,a,","); for(i=1;i<=n;i++) if(a[i]!="" && !index("," labels,"," a[i] ",")) return 0
      return 1
    }
    function proto(s) { return s=="" ? "TCP" : s }
    function nocomma(s) { sub(/,$/,"",s); return s }
    function endpoints(k) { return es=="ok" ? (ER[k]+0) " ready / " (EB[k]+0) " unready / " (EU[k]+0) " unknown" : "unknown" }
    FILENAME==sf && $1=="S" { k=$2 SUBSEP $3; if(!(k in SN)) SK[++NS]=k; SN[k]=$2 "/" $3; ST[k]=clean($4); EXT[k]=clean($5); IP[k]=clean($6); SEL[k]=nocomma(clean($7)); next }
    FILENAME==sf && $1=="T" { k=$2 SUBSEP $3; n=++NT[k]; TN[k,n]=clean($4); TP[k,n]=clean($5); TT[k,n]=clean($6); PT[k,n]=proto(clean($7)); next }
    FILENAME==pf && $1=="P" { k=$2 SUBSEP $3; PK[++NP]=k; PN[k]=$2 "/" $3; PNS[k]=$2; READY[k]=$5; LABELS[k]=$6; DEL[k]=clean($8); next }
    FILENAME==pf && $1=="C" && clean($5)!="" { PORT[$2 SUBSEP $3 SUBSEP $5 SUBSEP proto(clean($7))]=1; next }
    FILENAME==ef && $1=="E" { k=$2 SUBSEP $3; EC[k]++; next }
    FILENAME==ef && $1=="D" {
      k=$2 SUBSEP $3; if($8=="true") ER[k]++; else if($8=="false") EB[k]++; else EU[k]++
      if($7=="Pod") { ns=clean($5); if(ns=="") ns=$2; p=ns SUBSEP clean($6); EK[k,p]=1; if($8=="true" && $10!="true") EPR[k,p]=1 }
      next
    }
    FILENAME==inf && $1=="I" { IR[++NI]=$0; next }
    END {
      for(si=1;si<=NS;si++) {
        k=SK[si]; split(k,z,SUBSEP)
        if(SEL[k]!="" && ST[k]!="ExternalName" && ps=="ok") for(pi=1;pi<=NP;pi++) {
          p=PK[pi]; if(PNS[p]!=z[1] || !matches(SEL[k],LABELS[p])) continue
          MATCH[k,p]=1; SELECTED[k]++; if(READY[p]=="True" && DEL[p]=="") { PR[k]++; if(PR[k]<=3) PLIST[k]=PLIST[k] (PLIST[k]=="" ? "" : ", ") PN[p] }
          for(ti=1;ti<=NT[k];ti++) if(TT[k,ti]!="" && TT[k,ti]!~/^[0-9]+$/ && !((p SUBSEP TT[k,ti] SUBSEP PT[k,ti]) in PORT)) MISSING[k,ti]++
        }
      }
      print "\nINGRESS -> SERVICE -> ENDPOINTS -> READY PODS"
      if(ins!="ok") print "  Ingress routes unknown: optional source " ins "."
      else if(NI==0) print "  No service-backed Ingress routes in this collected scope (resource backends are not expanded)."
      else for(i=1;i<=NI;i++) {
        split(IR[i],r,"|"); k=r[2] SUBSEP r[7]; host=clean(r[5]); if(host=="") host="*"
        printf "  %s/%s  %s%s -> %s/%s:%s\n",r[2],r[3],host,r[6],r[2],r[7],r[8]
        if(ss!="ok") { print "    Service and backend relationship unknown: services source " ss "."; continue }
        if(!(k in SN)) { print "    Service missing from the successful service read."; continue }
        found=0; for(j=1;j<=NT[k];j++) if(r[8]==TN[k,j] || r[8]==TP[k,j]) found=1
        if(!found) print "    Ingress backend port does not match a Service port."
        if(ST[k]=="ExternalName") print "    ExternalName DNS alias -> " EXT[k] "; pod backend readiness is not inferred."
        else printf "    %s slices; endpoints %s; ready selected pods %s\n",(es=="ok" ? EC[k]+0 : "unknown"),endpoints(k),(ps=="ok" && SEL[k]!="" ? PR[k]+0 : "unknown")
      }
      print "\nSERVICE BACKEND DIAGNOSTICS"
      printf "  %-36s %-13s %-10s %-10s %s\n","NAMESPACE/SERVICE","TYPE","SELECTED","READY PODS","ENDPOINT READINESS"
      if(ss!="ok") { print "  Service inventory unknown: source " ss "."; exit }
      if(NS==0) print "  No Services in this successful scoped read."
      for(si=1;si<=NS;si++) {
        k=SK[si]; selected=(ps=="ok" && SEL[k]!="" && ST[k]!="ExternalName")
        printf "  %-36s %-13s %-10s %-10s %s\n",SN[k],ST[k],(selected ? SELECTED[k]+0 : "unknown"),(selected ? PR[k]+0 : "unknown"),endpoints(k)
        if(ST[k]=="ExternalName") { print "    DNS alias -> " EXT[k] "; selectors and EndpointSlices are not required for this Service type."; continue }
        if(SEL[k]=="") print "    Selectorless Service: backends can be managed manually; no selector mismatch is inferred."
        else {
          print "    selector: " SEL[k]
          if(ps!="ok") print "    Pod selection and named target ports unknown: pods source " ps "."
          else if(SELECTED[k]==0) print "    SELECTOR MISMATCH: selector matches no pods in this collected scope."
          else if(PR[k]==0) print "    UNREADY: selected pods exist, but none are Ready and non-terminating."
          else print "    Ready selected pods: " PLIST[k] (PR[k]>3 ? " (+" (PR[k]-3) " more)" : "")
        }
        for(ti=1;ti<=NT[k];ti++) {
          printf "    port %s%s/%s -> targetPort %s\n",(TN[k,ti]!="" ? TN[k,ti] ":" : ""),TP[k,ti],PT[k,ti],(TT[k,ti]!="" ? TT[k,ti] : TP[k,ti])
          if(selected && MISSING[k,ti]>0) printf "    NAMED PORT MISSING: %s/%s absent on %d/%d selected pods.\n",TT[k,ti],PT[k,ti],MISSING[k,ti],SELECTED[k]
        }
        if(es=="ok") {
          if(EC[k]==0) print "    No EndpointSlices for this Service in the successful slice read."
          else if(ER[k]==0) print "    No explicitly ready endpoints observed; unknown readiness remains unknown."
          linked=0; readyLinked=0
          for(ep in EK) { split(ep,pp,SUBSEP); if(pp[1] SUBSEP pp[2]!=k) continue; p=pp[3] SUBSEP pp[4]; linked++; if(EPR[k,p] && READY[p]=="True" && DEL[p]=="") readyLinked++ }
          if(linked>0 && ps=="ok") printf "    EndpointSlice Pod references: %d unique; explicitly ready endpoints pointing to Ready pods: %d.\n",linked,readyLinked
        } else print "    EndpointSlice backend state unknown: source " es "."
        if(IP[k]=="None") print "    Headless Service: DNS/backend records apply; there is no virtual ClusterIP."
      }
      print "\nReadiness is an API observation. DNS, ingress controllers, NetworkPolicy, routing, TLS and application responses are not tested."
    }
  ' "$TOOLKIT_DIR/health-services.raw" "$TOOLKIT_DIR/health-pods.raw" "$TOOLKIT_DIR/health-endpoints.raw" "$TOOLKIT_DIR/health-ingresses.raw"
}

health__storage_events() {
  local file=''
  if [ -r "$TOOLKIT_DIR/events.tsv" ]; then file="$TOOLKIT_DIR/events.tsv"
  elif [ -n "${MODEL:-}" ] && [ -r "$MODEL/events.tsv" ]; then file="$MODEL/events.tsv"; fi
  printf '\nSTORAGE-RELATED RECORDED EVENTS\n'
  if [ -z "$file" ]; then
    printf '  Event data is unavailable in this snapshot; inspect the Events view for mount, attach and provisioning failures.\n'
    return 0
  fi
  awk -F'\t' '
    NR==1 { header=$0; if(tolower($0) ~ /message|reason/) { next } }
    tolower($0) ~ /failedmount|failedattach|failedbinding|failedprovision|provisioningfailed|volume|persistentvolumeclaim|storageclass|claim/ {
      if(n++==0 && header!="") print "  " header
      if(n<=12) print "  " $0
    }
    END { if(n==0) print "  No matching storage entries in the available event file; scope and collection window apply."
      else if(n>12) print "  Additional matching events are available in the Events view." }
  ' "$file"
}

health_render_storage() {
  printf 'PERSISTENT STORAGE\n'
  printf 'PVC/PV capacity describes allocation; measured usage is shown only when PVC-labelled volume samples exist.\n'
  health__sources pvcs pods pvs storageclasses volume-metrics
  local source
  for source in pvcs pods pvs storageclasses; do
    [ -f "$TOOLKIT_DIR/health-$source.raw" ] || : > "$TOOLKIT_DIR/health-$source.raw"
  done
  [ -f "$TOOLKIT_DIR/health-volume-usage.tsv" ] || : > "$TOOLKIT_DIR/health-volume-usage.tsv"
  awk -F'|' -v qf="$TOOLKIT_DIR/health-pvcs.raw" -v pf="$TOOLKIT_DIR/health-pods.raw" \
    -v vf="$TOOLKIT_DIR/health-pvs.raw" -v cf="$TOOLKIT_DIR/health-storageclasses.raw" \
    -v uf="$TOOLKIT_DIR/health-volume-usage.tsv" -v qs="$(health__state pvcs)" \
    -v ps="$(health__state pods)" -v vs="$(health__state pvs)" \
    -v cs="$(health__state storageclasses)" -v us="$(health__state volume-metrics)" -v now="$(date +%s)" '
    function clean(s) { return (s=="<no value>" || s=="<nil>" || s=="null") ? "" : s }
    function known(s) { return clean(s)=="" ? "unknown" : s }
    function nocomma(s) { sub(/,$/,"",s); return s }
    function bytes(s,   n,i,a) {
      if(s=="?" || s=="") return "unknown"; n=s+0; split("B KiB MiB GiB TiB PiB",a," "); i=1
      while(n>=1024 && i<6) { n/=1024; i++ } return sprintf("%.1f%s",n,a[i])
    }
    function sample(ts,origin,   age) {
      if(ts=="?" || ts=="") return "unknown"; age=now-ts; if(age<0) return "clock ahead"
      return sprintf("%ds ago (%s time)%s",age,origin,(age>300 ? " STALE" : ""))
    }
    FILENAME==qf && $1=="Q" { k=$2 SUBSEP $3; QK[++NQ]=k; QN[k]=$2 "/" $3; QPH[k]=clean($4); QPV[k]=clean($5); QC[k]=clean($6); QR[k]=clean($7); QCAP[k]=clean($8); QA[k]=nocomma(clean($9)); QM[k]=clean($10); next }
    FILENAME==qf && $1=="F" && $5=="True" { k=$2 SUBSEP $3; COND[k]=COND[k] " " $4 ":" clean($6); next }
    FILENAME==pf && $1=="P" { k=$2 SUBSEP $3; PP[k]=$4 "/" $5; next }
    FILENAME==pf && $1=="V" { p=$2 SUBSEP $3; k=$2 SUBSEP $5; VCLAIM[p,$4]=k; REF[k,p]=1; next }
    FILENAME==pf && $1=="M" { p=$2 SUBSEP $3; MK[++NM]=p SUBSEP $5; MC[NM]=$4; MP[NM]=$6; MRO[NM]=$7; next }
    FILENAME==vf && $1=="Z" { PV[$2]=1; VPH[$2]=clean($3); VC[$2]=clean($4); VCAP[$2]=clean($5); VR[$2]=clean($6); VCLAIM[$2]=clean($7) "/" clean($8); DRIVER[$2]=clean($9); next }
    FILENAME==cf && $1=="K" { SC[$2]=1; PROV[$2]=clean($3); BIND[$2]=clean($4); EXPAND[$2]=clean($5); RECLAIM[$2]=clean($6); next }
    FILENAME==uf {
      split($0,u,"\t"); k=u[1] SUBSEP u[2]; USED[k]=u[3]; UT[k]=u[4]; UO[k]=u[5]; CAP[k]=u[6]; CT[k]=u[7]; CO[k]=u[8]; AVAIL[k]=u[9]; AT[k]=u[10]; AO[k]=u[11]; next
    }
    END {
      print "\nPVC BINDINGS AND POD REFERENCES"
      printf "  %-34s %-10s %-20s %-13s %-13s %s\n","NAMESPACE/CLAIM","PHASE","PV","REQUEST","PVC CAPACITY","STORAGECLASS"
      if(qs!="ok") print "  PVC inventory and binding completeness unknown: source " qs "."
      else if(NQ==0) print "  No PVCs in this successful scoped read."
      if(qs=="ok") for(i=1;i<=NQ;i++) {
        k=QK[i]; v=QPV[k]; c=QC[k]
        printf "  %-34s %-10s %-20s %-13s %-13s %s\n",QN[k],known(QPH[k]),(v!="" ? v : "unbound"),known(QR[k]),known(QCAP[k]),(c!="" ? c : "unspecified")
        printf "    access=%s; volumeMode=%s\n",known(QA[k]),known(QM[k])
        if(COND[k]!="") print "    PVC conditions:" COND[k]
        if(v!="") {
          if(vs!="ok") print "    PV details unknown: optional source " vs "."
          else if(!(v in PV)) print "    BINDING CHECK: referenced PV missing from the successful PV read."
          else {
            printf "    PV phase=%s; capacity=%s; reclaim=%s; driver=%s\n",known(VPH[v]),known(VCAP[v]),known(VR[v]),known(DRIVER[v])
            if(VCLAIM[v]!="/" && VCLAIM[v]!=QN[k]) print "    BINDING CHECK: PV claimRef points to " VCLAIM[v] ", not " QN[k] "."
          }
        }
        if(c!="") {
          if(cs!="ok") print "    StorageClass details unknown: optional source " cs "."
          else if(!(c in SC)) print "    StorageClass missing from the successful class read."
          else {
            printf "    StorageClass provisioner=%s; binding=%s; expansion=%s\n",known(PROV[c]),known(BIND[c]),known(EXPAND[c])
            if(QPH[k]=="Pending" && BIND[c]=="WaitForFirstConsumer") print "    Pending claim uses WaitForFirstConsumer; scheduling/consumer placement may be required before binding."
          }
        }
        refs=0
        if(ps!="ok") print "    Pod volume references and mounts unknown: pods source " ps "."
        else {
          for(r in REF) { split(r,a,SUBSEP); if(a[1] SUBSEP a[2]!=k) continue; p=a[3] SUBSEP a[4]; refs++
            printf "    pod reference: %s/%s (%s)\n",a[3],a[4],known(PP[p])
          }
          if(refs==0) print "    No pod volume references in this collected scope; this does not establish that storage is unused."
          for(m=1;m<=NM;m++) if(VCLAIM[MK[m]]==k) {
            split(MK[m],a,SUBSEP); printf "    declared mount: %s/%s container=%s path=%s readOnly=%s\n",a[1],a[2],MC[m],MP[m],(MRO[m]=="true" ? "true" : "false")
          }
        }
        if(us=="ok" && (k in USED)) {
          printf "    measured used=%s; measured filesystem capacity=%s; available=%s",bytes(USED[k]),bytes(CAP[k]),bytes(AVAIL[k])
          skew=UT[k]-CT[k]; if(skew<0) skew=-skew
          if(USED[k]!="?" && CAP[k]!="?" && CAP[k]+0>0 && skew<=300) printf "; used/capacity=%.1f%%",100*USED[k]/CAP[k]
          else if(USED[k]!="?" && CAP[k]!="?" && skew>300) printf "; percentage unknown (sample times differ by more than 5m)"
          printf "\n    usage sample: %s; capacity sample: %s; available sample: %s\n",sample(UT[k],UO[k]),sample(CT[k],CO[k]),sample(AT[k],AO[k])
        } else print "    Measured usage unknown: no usable PVC-labelled volume sample for this claim."
      }
      if(ps=="ok" && qs=="ok") for(r in REF) {
        split(r,a,SUBSEP); k=a[1] SUBSEP a[2]
        if(!(k in QN)) printf "  MISSING PVC REFERENCE: pod %s/%s refers to %s/%s, absent from the successful scoped PVC read.\n",a[3],a[4],a[1],a[2]
      }
      print "\nPod volume references and declared mount paths do not prove a volume mounted successfully."
      print "Measured filesystem samples can differ from PVC/PV allocation; missing samples never mean zero usage."
    }
  ' "$TOOLKIT_DIR/health-pvcs.raw" "$TOOLKIT_DIR/health-pods.raw" "$TOOLKIT_DIR/health-pvs.raw" "$TOOLKIT_DIR/health-storageclasses.raw" "$TOOLKIT_DIR/health-volume-usage.tsv"
  health__storage_events
}
