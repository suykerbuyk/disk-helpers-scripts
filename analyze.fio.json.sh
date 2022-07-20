#!/bin/sh
#../analyze.fio.json.sh | sed 's/-/,/g' | sed 's/.fio.json//g' | sed  's/\t/,/g' | sed 's/  /,/g' 
classic_analysis() {
for F in $(ls *.json)
do
	echo -n "$F  ," |\
        sed 's/-/,/g 
             s/.fio.json//g
	     s/,4[Kk],/,4K,4096,/g 
	     s/,8[Kk],/,8K,8192,/g 
	     s/,16[Kk],/,16K,16384,/g 
	     s/,32[Kk],/,32K,32768,/g 
	     s/,64[Kk],/,64K,65536,/g 
	     s/,128[Kk],/,128K,131072,/g 
	     s/,256[Kk],/,256K,262144,/g 
	     s/,512[Kk],/,512K,524288,/g 
	     s/,1024[Kk],/,1M,524288,/g 
	     s/,1[Mm],/,1M,1048576,/g 
	     s/,2[Mm],/,2M,2097152,/g 
	     s/,2048[Kk],/,2M,2097152,/g 
	     s/,4[Mm],/,4M,4194304,/g 
	     s/,8[Mm],/,8M,8388608,/g 
	     s/,16[Mm],/,16M,16777216,/g'
	cat $F | jq -r '.jobs[0] | [.read.iops, .write.iops, .read.bw_bytes/1024/1024, .write.bw_bytes/1024/1024] | @csv'
#sed -e 's/-/,/g ; s/.fio.json//g ; s/\t/,/g ; s/  /,/g' 
done
}

if [ ! -e ./test.filter ]; then
cat <<EOF >./test.filter
[.timestamp] \
+ (.jobs[] \
| [.jobname, \
."job options".rw,\
."job options".bs,\
."job options".numjobs,\
."job options".runtime,\
."job options".iodepth,\
."job options".ioengine,\
."job options".size,\
.read.iops,\
.write.iops,\
.read.lat_ns.mean/1000,\
.write.lat_ns.mean/1000,\
.read.bw_bytes/1024/1024,\
.write.bw_bytes/1024/1024] ) | @csv
EOF
fi


new_analysis() {
echo "Timestamp,JobName,Operation,BlockSize,ThreadCount,RunTime,IoDepth,IoEngine,FileSize,ReadIOPs,WriteIOPs,ReadLatMicroSec,WriteLatMicroSec,ReadBW(MiB),WriteBW(MiB)"
for F in $(ls *.json)
do
	jq -r -f ./test.filter $F | tr -d '"'
done
}

new_analysis
