#!/bin/sh
for ENC in $(lsscsi -g | grep enc | grep SEAGATE | awk '{print $7}')
do
    for X in $(seq 0 83)
        do echo -n  "$ENC $X  "
            sg_ses --index ${X} --get=locate ${ENC}
    done
done
