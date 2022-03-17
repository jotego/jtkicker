#!/bin/bash

cd $JTUTIL/src
make || exit $?
cd -
echo "------------"

mkdir -p mra/_alt

for i in mikie kicker yiear sbaskt roadf; do
    mame2mra -toml $i.toml -core $i $*
done

sshpass -p 1 scp -r mra/* root@MiSTer.home:/media/fat/_JT
