#!/usr/bin/bash

path=(/home/*)

clear_log(){
	if [ $(du -s ${path[0]}/clean.log | awk '{print $1}') -gt 12 ];then
	    > ${path[0]}/clean.log
	fi
}

convert_to_GB(){
    echo $1 | awk '{$1=$1/(1024^2); printf "%.2f %s\n", $1,"GB";}'
}

add_to_log(){
    echo "$1: $2" >> ${path[0]}/clean.log
}

calculate_GB(){
    fin=$(convert_to_GB $1)
}

calculate_total(){
    total=$((total + cache))
}

calculate_size(){
    if [ "$1" != "Edge cache" ];then
	    cache=$(du -s $2 | awk '{print $1}')
	else
	    cache=$(($(du -s $2 | awk '{print $1}') + $(du -s "$3" | awk '{print $1}')))
	fi
	calculate_GB $cache
	if [ "$fin" != "0.00 GB" ];then
	        calculate_total
		if [ "$1" == "DNF cache" ];then
		    dnf clean all > /dev/null
		elif [ "$1" == "Edge cache" ];then
		    rm -rf $2/* $3/*
		else
		    rm -rf $2/*
		fi
		echo -e "Deleted \033[0;35m$1: \033[0m"$fin
                add_to_log "$1" "$fin"
    fi
}

clear_log

echo "-----$(date +'%d/%m/%y %r')-----" >> ${path[0]}/clean.log

calculate_size "Thumbnails cache" "${path[0]}/.cache/thumbnails/x-large"
calculate_size "Edge cache" "${path[0]}/.cache/microsoft-edge/Default/Cache/Cache_Data" "${path[0]}/.cache/microsoft-edge/Default/Code Cache/js"
calculate_size "Firefox cache" "${path[0]}/.cache/mozilla/firefox/$(ls ${path[0]}/.cache/mozilla/firefox)/cache2/entries"
calculate_size "DNF cache" "/var/cache/libdnf5"
calculate_size "Coredumps" "/var/lib/systemd/coredump"
calculate_size "Journal logs" "/var/log/journal"

nvidia=(nsight-compute nsight-systems)
for i in "${nvidia[@]}"
do
	x=$(ls -l "/opt/nvidia/$i" | grep -c ^d)
	if [ $x -gt 1 ];then
		readarray a < <(ls "/opt/nvidia/$i")
		echo -e "Total folders in \033[0;35m$i\033[0m: \033[0;36m${#a[@]}\033[0m"
		IFS=$'\n'           ## only word-split on '\n'
		a=( $(printf "%s\n" ${a[@]} | sort -r ) )  ## reverse sort
		echo -e "Keeping \033[0;32m$a\033[0m"
		unset a[0]
	        cache=0
	        j="0"
		for j in "${a[@]}"
		do
		   nvidia_cache=$(du -s /opt/nvidia/$i/$j | awk '{print $1}')
		   cache=$(($cache + $nvidia_cache))
		   sudo rm -rf "/opt/nvidia/$i/$j"
		   echo -e "Deleted \033[0;31m$j: \033[0m"$(convert_to_GB $nvidia_cache $i)
		done
		add_to_log $i $(convert_to_GB $cache)
		calculate_total
	fi
done

x=$(ls "/usr/local" | grep "cuda-" | wc -l)
if [ $x -gt 2 ];then
	readarray a < <(ls /usr/local | grep "cuda-[1-9][1-9]$" | sort -r)
	readarray b < <(ls /usr/local | grep "cuda-[1-9][1-9].[1-9]$" | sort -r)
	echo -e "Total folders of major versions \033[0;35mcuda-xx\033[0m: \033[0;36m${#a[@]}\033[0m"
	echo -e "Total folders of minor versions \033[0;35mcuda-xx.x\033[0m: \033[0;36m${#b[@]}\033[0m"
	IFS=$'\n'           ## only word-split on '\n'
	a=( $(printf "%s\n" ${a[@]}) )
	b=( $(printf "%s\n" ${b[@]}) )
	if [ ${#a[@]} -gt 1 ];then
		echo -e "Keeping \033[0;32m$a\033[0m"
		unset a[0]
		for i in "${a[@]}"
		do
		   sudo unlink "/usr/local/$i"
		   echo -e "Deleted \033[0;31m$i\033[0m"
		done
	fi
	if [ ${#b[@]} -gt 1 ];then
		echo -e "Keeping \033[0;32m$b\033[0m"
		unset b[0]
		cache=0
		for i in "${b[@]}"
		do
		   cuda_cache=$(du -s /usr/local/$i | awk '{print $1}')
		   cache=$(($cache + $cuda_cache))
		   sudo rm -rf "/usr/local/$i"
		   echo -e "Deleted \033[0;31m$i: \033[0m"$(convert_to_GB $cuda_cache)
		done
		add_to_log "Cuda" $(convert_to_GB $cache)
		calculate_total
	fi
fi

add_to_log "Total storage recovered" $(convert_to_GB $total)
echo -e "\nTotal storage recovered: \033[0;32m$(convert_to_GB $total)\033[0m"