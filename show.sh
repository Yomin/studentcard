#!/bin/bash

[ $# -ne 1 ] && { echo "Usage: $0 dump.mfd"; exit 0; }

file=$1
blocklist="10 20 60 80 90 a0 c0 d0 e0 100 110 120 140 150 160 260 280 290 2a0 2e0 300 310 320 360 380 390 3a0"
vblocklist="40 50 240 250 2c0 2d0 240 250"

[ -e $file ] || { echo No such file; exit 1; }

# show pos len
function show () {
	xxd -u -p -s $1 -l $2 $file
}

# showdisc pos len
function showdisc () {
	local str=$(xxd -u -g 1 -s $1 -l $2 $file)
	str=${str:9}
	echo ${str:0:$((16*3-1))}
}

# toDec hexstring
function toDec () {
	echo "ibase=16; $1" | bc
}

# showAscii pos len
function showAscii () {
	xxd -u -g 0 -s $1 -l $2 $file | tr -s " " | cut -d" " -f3
}

# putDots dir string pos1 [pos2,...]
function putDots () {
	local dir=$1
	local string=$2
	shift
	shift
	local x
	local n=0
	if [ $dir -eq 0 ]; then
		for x in $@; do
			string=${string:0:$(($x + $n))}"."${string:$(($x + $n))}
			n=$(($n + 1))
		done
	else
		len=${#string}
		for x in $@; do
			string=${string:0:$(($len - $x))}"."${string:$(($len - $x))}
		done
	fi
	echo $string
}

# showCash cash
function showCash () {
	local cash=$1
	local neg=0
	[ $cash -gt $((0x7FFFFFFF)) ] && {
		cash=$((($cash-0xFFFFFFFF-1)*-1)); neg=1; }
	[ $cash -lt 100 ] && cash="0"$cash
	[ $cash -lt 10 ] && cash="0"$cash
	[ $neg -eq 1 ] && cash="-"$cash
	putDots 1 $cash 2
}

# showDate day month year
function showDate () {
	local day=$1
	local mon=$2
	local yea=$3
	[ $day -lt 10 ] && day="0"$day
	[ $mon -lt 10 ] && mon="0"$mon
	[ $yea -lt 1000 ] && yea="0"$yea
	[ $yea -lt 100 ] && yea="0"$yea
	[ $yea -lt 10 ] && yea="0"$yea
	echo $day"."$mon"."$yea
}

# showTime hours minutes
function showTime () {
	local hou=$1
	local min=$2
	[ $hou -lt 10 ] && hou="0"$hou
	[ $min -lt 10 ] && min="0"$min
	echo $hou":"$min
}

# showStudent distinctionbyte
function showStudent () {
	[ $1 -eq 0 ] && echo yes || echo no
}

# showID pos length bitmask[adddecimal|parity|inverted]
function showID () {
	id=""
	parity=""
	decimal=""
	pos=$(echo "ibase=16; ${1:2}"|bc)
	if [ $(($3&1)) -eq 0 ]; then
		id=$(show $1 $2)
	else
		for (( x=0; x<$2; x++ )); do
			id=$(show $(($pos+$x)) 1)$id
		done
	fi
	if [ $(($3&2)) -ne 0 ]; then
		parity="/"$(show $(($pos+$2)) 1)
	fi
	if [ $(($3&4)) -ne 0 ]; then
		decimal=" ("$(toDec $id)")"
	fi
	echo $id$parity$decimal
}

# getReader readerbyte
function getReader () {
	case $1 in
	65) echo "Mensa 1st floor right" ;;
	66) echo "Mensa 1st floor middle" ;;
	67) echo "Mensa 1st floor left" ;;
	00) echo "Mensa 2nd floor left" ;;
	68) echo "Mensa 2nd floor right" ;;
	6A) echo "Cafeteria Mensa" ;;
#	  ) echo "Cafeteria Library" ;;
	6C) echo "Cafeteria Physics" ;;
	13) echo "Mensa Bottle Return Station" ;;
	14) echo "Mensa Charger left" ;;
	15) echo "Mensa Charger right" ;;
	2B) echo "Library Charger" ;;
	02) echo "URZ RTL1" ;;
	 *) echo "unknown" ;;
	esac
}

# checkBlock startbyte
function checkBlock () {
	local list=$(showdisc 0x$1 16)
	list="0x"${list//" "/"^0x"}
	[ $(($list)) -eq 255 ] && return 0 || return 1
}

# checkVBlock startbyte
function checkVBlock () {
	local value=$((0x$(show 0x$1 4)))
	local valinv=$(($value^0xFFFFFFFF))
	local address=$(show $((0x$1+12)) 1)
	local addinv=$(($address^0xFF))
	[ $value   -eq $((0x$(show $((0x$1+8)) 4))) -a \
	  $valinv  -eq $((0x$(show $((0x$1+4)) 4))) -a \
	  $address -eq $((0x$(show $((0x$1+14)) 1))) -a \
	  $addinv  -eq $((0x$(show $((0x$1+13)) 1))) -a \
	  $addinv  -eq $((0x$(show $((0x$1+15)) 1))) \
	] && return 0 || return 1
}

# checkBlocks blocklist vblocklist
function checkBlocks () {
	local x
	for x in $1; do
		checkBlock $x  || { echo "corrupt at 0x$x"; return 1; }
	done
	for x in $2; do
		checkVBlock $x || { echo "corrupt at 0x$x"; return 1; }
	done
	echo ok
	return 0
}

echo "Card UID:              "$(showID 0x0 4 6)
echo "Manufacturer Info:     "$(show 0x5 11)
echo "Manufactured:          "$(showDate $(toDec $(show 0x282 1)) $(toDec $(show 0x283 1)) $(toDec $(show 0x284 2))) \
                              $(showTime $(toDec $(show 0x286 1)) $(toDec $(show 0x287 1)))
echo "Card ID:               "$(showID 0x27 3 5)
echo "Student:               "$(showStudent $(show 0xd3 1))
echo "Matrikel Number:       "$(show 0xd4 3)
echo "card validity end:     "$(putDots 0 $(show 0xc0 4) 2 4)
echo "Library Number:        "$(showAscii 0x141 11)
echo "Money Amount:          "$(showCash $(toDec $(show 0x43 1)$(show 0x42 1)$(show 0x41 1)$(show 0x40 1)))
echo "Last Charged:          "$(showDate $(toDec $(show 0x82 1)) $(toDec $(show 0x83 1)) $(toDec $(show 0x84 2))) \
                              $(showTime $(toDec $(show 0x86 1)) $(toDec $(show 0x87 1)))
echo "Where Last Charged:    "$(getReader $(show 0x81 1))
echo "Charging Amount:       "$(showCash $(toDec $(show 0x8a 2)))
echo "Last Bought:           "$(showDate $(toDec $(show 0x92 1)) $(toDec $(show 0x93 1)) $(toDec $(show 0x94 2))) \
                              $(showTime $(toDec $(show 0x96 1)) $(toDec $(show 0x97 1)))
echo "Where Last Bought:     "$(getReader $(show 0x91 1))
echo "Purchases:             "$(toDec $(show 0x9e 1))
echo "Checkblocks:           "$(checkBlocks "$blocklist" "$vblocklist")

exit 0
