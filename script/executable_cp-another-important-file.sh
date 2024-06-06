aifdir="/home/hydroakri/AIF"
mkdir -p $aifdir/etc/default
mkdir -p $aifdir/etc/mkinitcpio.d/
mkdir -p $aifdir/etc/modprobe.d/
mkdir -p $aifdir/etc/modules-load.d/
mkdir -p $aifdir/etc/sysctl.d/
cp -r /etc/default $aifdir/etc/
cp -r /etc/mkinitcpio.d/ $aifdir/etc/
cp -r /etc/modprobe.d/ $aifdir/etc/
cp -r /etc/modules-load.d/ $aifdir/etc/
cp -r /etc/sysctl.d $aifdir/etc/
cp /etc/fstab $aifdir/etc/
cp /etc/environment $aifdir/etc/
cp /etc/mkinitcpio.conf $aifdir/etc/
cp /etc/tlp.conf $aifdir/etc/
doas chmod -R 777 $aifdir
doas chown -R -c hydroakri:hydroakri $aifdir

systemctl list-units --type=service --state=running > $aifdir/enabled-service.txt
systemctl list-timers --state=active > $aifdir/active-timers.txt
pacman -Qqe > $aifdir/pkgs.txt
flatpak list > $aifdir/flatpak.txt

