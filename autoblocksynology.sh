#!/bin/sh

###############################################################################
###############################################################################
# Script du tutoriel de nas-forum.com par PPJP + Superthx pour test
###############################################################################
# Ce script accepte un paramètre:  "raz"
# S'il est présent:
# le script débute par la suppression des IP non bloquées définitivement
###############################################################################
### PARAMETRAGE ###
###################
# Indiquer la fréquence de lancement de ce script en heures
#(exemples: 1 si chaque heure, 24 si journalier)
Freq="1" 

# Adresses des sites source séparées par un espace
Liste_Url="https://lists.blocklist.de/lists/ \
https://mariushosting.com/wp-content/uploads/2018/07/deny-ip-list.txt"
# Pour la liste de www.blocklist.de
# Liste de choix: {all} {ssh} {mail} {apache} {imap} {ftp} {sip} {bots}
#              {strongips} {ircbot} {bruteforcelogin}
Choix="all"

#Fichier personnel facultatif listant des IP (1 par ligne) à bloquer
Filtre_Perso="filtreperso.txt"

# Pour trace facultative des IP non conformes au format IP v4 ou v6
#Choix: {0}: sans trace, {1}: dans fichier log, {2}: dans fichier spécifique
Trace_Ano=1
File_Ano="anoip.txt" # à renseigner si option2 (sinon ne pas supprimer)

###############################################################################
###############################################################################
### CONSTANTES ###
##################
Version="v0.0.1"
db="/etc/synoautoblock.db"
dirtmp="/tmp/autoblock_synology"
filetemp1="/fichiertemp1"
filetemp2="/fichiertemp2"
marge=60

###############################################################################
### FONCTIONS ###
#################
raz_ip_bloquees(){
sqlite3 $db <<EOL
delete from AutoBlockIP where DENY = 1 and ExpireTime > 0;
EOL
}

###############################################################################
tests_initiaux(){
echo -e "\nDemarrage du script `basename $0` $Version: $(date)"
if [ -f  "/bin/bash" ]; then
    TypeShell="bash"
elif [ -f  "/bin/sh" ]; then    
    TypeShell="sh"
else
    echo -e "Erreur dans le script\nAbandon du script"
    exit 1
fi
if [[ $# -gt 0 ]]; then
    if [[ "$1" == "raz" ]]; then
        raz_ip_bloquees
        echo "Le blocage des IP non bloquées définitivement a été supprimé"
    else
        echo -e "Parametre $1 incorrect!\nSeul parametre autorisé: 'raz'"
        echo "Abandon du script"
        exit 1
    fi
fi
if [ ! -d  "/tmp" ]; then  # par sécurité
    echo   -e "Le dossier tmp n'existe pas\nAbandon du script" # par sécurité
    exit 1 # par sécurité
elif [ ! -d  $dirtmp ]; then
    mkdir $dirtmp
    chmod 755 $dirtmp
fi
}

###############################################################################
plage_blocage(){
start=`date +%s`
block_off=$((start+Freq*2*3600+$marge))
sqlite3 $db <<EOL
drop table if exists Var;
create table Var (name text primary key, value text);
EOL
`sqlite3 $db "insert into Var values ('stop', $block_off)"`
}

###############################################################################
raz_fil_ano(){
if [ -f  $File_Ano ]; then
    rm  $File_Ano
fi
if [[ $Trace_Ano == 2 ]]; then
    echo -e "\nDemarrage du script $Version: $(date)" > $File_Ano
fi
}

###############################################################################
acquisition_ip(){
tmp1=${dirtmp}${filetemp1}
tmp2=${dirtmp}${filetemp2}
if [ -f  $Filtre_Perso ];then
    cat "$Filtre_Perso" > $tmp1
else
    touch $tmp1
    touch $Filtre_Perso
fi
for url in $Liste_Url; do
	host=`echo $url | sed -n "s/^https\?:\/\/\([^/]\+\).*$/\1/p"`
	case $host in
		lists.blocklist.de)
			nb=0
			for chx in $Choix; do
			    wget -q "$url$chx.txt" -O $tmp2
			    nb2=$(wc -l $tmp2 | cut -d' ' -f1)
			    if [[ $nb2 -gt 0 ]];then
			        sort -ufo $tmp1 $tmp2 $tmp1
			        nb=$(($nb+$nb2))
			    else
                    echo "Echec chargement IP depuis le site $host$choix.txt"
                fi
            done
			;;
	    mariushosting.com)
		    if [[ $TypeShell == "bash" ]];then
		        an_mois=$(date '+%Y/%m')
		    elif [[ $TypeShell == "sh" ]];then
		        an_mois=$(busybox date -D '%s' +"%Y/%m")
		    fi
		    wget -q ${url:0:45}$an_mois${url:52} -O $tmp2
		    nb=$(wc -l  $tmp2 | cut -d' ' -f1)
			if [[ $nb -gt 0 ]];then
                sort -ufo $tmp1 $tmp2 $tmp1
            else
		        if [[ $TypeShell == "bash" ]];then
		            an_mois=$(date '+%Y/%m' -d "$start_date-7 days")
                elif [[ $TypeShell == "sh" ]];then
		            an_mois=$(busybox date -D '%s' +"%Y/%m" -d "$((`busybox date +%s`-86400*7))")
		        fi
		        wget -q ${url:0:45}$an_mois${url:52} -O $tmp2
		        nb=$(wc -l  $tmp2 | cut -d' ' -f1)
			    if [[ $nb -gt 0 ]];then
		            sort -ufo  $tmp1 $tmp2 $tmp1
                else
		            echo "Echec chargement IP depuis le site $host"
		        fi    
		    fi
            ;;
	    reserve)
	        wget -q "$url" -O $tmp2
			nb=$(wc -l $tmp2 | cut -d' ' -f1)
			if [[ $nb -gt 0 ]];then
			    sort -ufo $tmp1 $tmp2 $tmp1
			 else
                echo "Echec chargement IP depuis le site $host"
            fi
			;;
	    *)
			echo "Le traitement pour $url n'est pas implanté"
			nb=0
			;;
	esac
done
rm $tmp2
nb_ligne=$(wc -l  $tmp1 | cut -d' ' -f1)
}

###############################################################################
maj_ip_connues(){
sqlite3 $db <<EOL
drop table if exists Var;
create table Var (name text primary key, value text);
EOL
`sqlite3 $db "insert into Var values ('stop', $block_off)"
`sqlite3 $db <<EOL
drop table if exists Tmp;
create table Tmp (IP varchar(50) primary key);
.mode csv
.import /tmp/autoblock_synology/fichiertemp1 Tmp
alter table Tmp add column ExpireTime date;
alter table Tmp add column Old boolean;
update Tmp set ExpireTime = (select value from Var where name = 'stop');
update Tmp set Old = (
select 1 from AutoBlockIP where Tmp.IP = AutoBlockIP.IP);
update AutoBlockIP set ExpireTime=(
select ExpireTime from Tmp where AutoBlockIP.IP = Tmp.IP and Tmp.Old = 1) 
where exists (
select ExpireTime from Tmp where AutoBlockIP.IP = Tmp.IP and Tmp.Old = 1);
delete from Tmp where Old = 1;
drop table  Var;
EOL
rm $tmp1
}

###############################################################################
tracer_ip_incorrecte(){
case $Trace_Ano in
    1)  echo "$nb_invalide:IP non traitée (format IP incorrect):  $ip"
        ;;
    2)  echo "$nb_invalide : $ip" >> $File_Ano            
        ;;
    *) ;;
esac
}

###############################################################################
hex_en_dec(){
if [ "$1" != "" ];then
    printf "%d" "$(( 0x$1 ))"
fi
}

###############################################################################
maj_ipstd(){
ipstd=''
if [[ $ip != '' ]]; then
    if expr "$ip" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' > \
        /dev/null; then
        ipstd=$(printf "0000:0000:0000:0000:0000:FFFF:%02X%02X:%02X%02X" \
            ${ip//./' '})
    elif [[ $ip != "${1#*:[0-9a-fA-F]}" ]]; then
        ip6=$ip
        echo $ip6 | grep -qs "^:" && $ip6="0${ip6}"
        if echo $ip6 | grep -qs "::"; then
            sep=$(echo $ip6 | sed 's/[^:]//g')
            absent=$(echo ":::::::::" | sed "s/$sep//")
            rempl=$(echo $absent | sed 's/:/:0/g')
            ip6=$(echo $ip6 | sed "s/::/$rempl/")
        fi
        blocks=$(echo $ip6 | grep -o "[0-9a-f]\+")
        set $blocks
        ipstd=$(printf "%04X:%04X:%04X:%04X:%04X:%04X:%04X:%04X" \
            $(hex_en_dec $1) $(hex_en_dec $2) $(hex_en_dec $3) $(hex_en_dec $4) \
            $(hex_en_dec $5) $(hex_en_dec $6) $(hex_en_dec $7) $(hex_en_dec $8))
    else
        tracer_ip_incorrecte
    fi
    if [[ $ipstd != '' ]]; then 
        printf '%s,%s,%s,%s\n' "$ip" "$start" "$block_off" "$ipstd" >> $tmp1
    fi
fi
}

###############################################################################
import_nouvelles_ip(){
sqlite3 $db <<EOL
drop table Tmp;
create table Tmp (IP varchar(50) primary key, RecordTime date, 
ExpireTime date, IPStd varchar(50));
.mode csv
.import /tmp/autoblock_synology/fichiertemp1 Tmp
EOL
}

###############################################################################
insertion_nouvelles_ip_nas(){
sqlite3 $db <<EOL
insert into AutoBlockIP 
select IP, RecordTime, ExpireTime, 1, IPStd, NULL, NULL 
from Tmp where IPStd is not NULL;
drop table Tmp;
EOL
}

###############################################################################
insertion_nouvelles_ip_routeur(){
sqlite3 $db <<EOL
insert into AutoBlockIP 
select IP, RecordTime, ExpireTime, 1, IPStd 
from Tmp where IPStd is not NULL;
drop table Tmp;
EOL
}

###############################################################################
insertion_nouvelles_ip(){
newip=`sqlite3 $db "select IP from Tmp where IP <>''"`
tmp1=${dirtmp}${filetemp1}
for ip in $newip; do
   maj_ipstd
done
if [ -f  $tmp1 ]; then
    import_nouvelles_ip
    if [[ $TypeShell == "bash" ]];then
        insertion_nouvelles_ip_nas
	elif [[ $TypeShell == "sh" ]];then
    	insertion_nouvelles_ip_routeur
	fi    
	rm $tmp1
fi
}

###############################################################################
### SCRIPT ###
##############
cd `dirname $0`
tests_initiaux $1
plage_blocage
raz_fil_ano 
acquisition_ip
maj_ip_connues
insertion_nouvelles_ip 
echo  "Script terminé"
exit 0
###############################################################################
