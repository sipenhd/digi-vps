#!/bin/bash

# Jalankan semua perintah tanpa meminta konfirmasi
export DEBIAN_FRONTEND=noninteractive

# Update sistem & install dependensi tanpa prompt
echo "🔄 Updating system and installing dependencies..."
sudo apt update -y && sudo apt upgrade -y
sudo apt install -y qemu qemu-kvm virt-manager virtinst cloud-utils genisoimage wget unzip

# Buat folder kerja
mkdir -p ~/windows-vm
cd ~/windows-vm

# Download Windows ISO
ISO_URL="https://go.microsoft.com/fwlink/p/?linkid=2195587&clcid=0x409&culture=en-us&country=us"
ISO_FILE="windows.iso"

echo "🌍 Downloading Windows ISO..."
wget -O $ISO_FILE $ISO_URL

# Buat file autounattend.xml untuk instalasi otomatis
echo "📄 Creating autounattend.xml..."
cat <<EOF > autounattend.xml
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="windowsPE">
        <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <UserData>
                <ProductKey>
                    <Key>XXXXX-XXXXX-XXXXX-XXXXX-XXXXX</Key>
                    <WillShowUI>OnError</WillShowUI>
                </ProductKey>
                <AcceptEula>true</AcceptEula>
                <FullName>Administrator</FullName>
                <Organization>Company</Organization>
            </UserData>
        </component>
    </settings>
</unattend>
EOF

# Buat ISO untuk autounattend.xml
echo "📀 Creating autounattend ISO..."
genisoimage -o autounattend.iso -J -R autounattend.xml

# Buat disk image untuk Windows
DISK_FILE="windows.img"
echo "💾 Creating Windows disk image..."
qemu-img create -f qcow2 $DISK_FILE 50G

# Jalankan instalasi Windows tanpa interaksi manual
echo "🚀 Starting Windows installation..."
nohup qemu-system-x86_64 \
    -enable-kvm \
    -m 4096 \
    -cpu host \
    -smp 2 \
    -drive file=$DISK_FILE,format=qcow2 \
    -drive file=$ISO_FILE,media=cdrom \
    -drive file=autounattend.iso,media=cdrom \
    -boot order=d \
    -vnc :1 \
    -net nic -net user \
    -device usb-tablet \
    -device VGA \
    > qemu.log 2>&1 &

echo "✅ Installation started. Connect via VNC (:1) to monitor progress."

# Tunggu sebelum setting RDP
sleep 600  

# Buat skrip PowerShell untuk mengaktifkan RDP otomatis di Windows
echo "🔧 Setting up RDP..."
cat <<EOF > setup-rdp.ps1
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
EOF

# Simpan sebagai ISO & pasang di Windows
genisoimage -o setup-rdp.iso -J -R setup-rdp.ps1

echo "✅ RDP setup completed. You can now connect to Windows via RDP."
