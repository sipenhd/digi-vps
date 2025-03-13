#!/bin/bash

# **Update & Upgrade Sistem**
echo "🔄 Updating system..."
apt update && apt upgrade -y

# **Instalasi Paket yang Dibutuhkan**
echo "📦 Installing required packages..."
apt install -y wget qemu-kvm qemu-utils genisoimage net-tools

# **Variabel utama**
ISO_URL="https://go.microsoft.com/fwlink/p/?linkid=2195333"
ISO_PATH="/tmp/windows.iso"
OUTPUT_ISO="/tmp/windows-modified.iso"
WINDOWS_IMG="/tmp/windows.img"
TEMP_DIR="/mnt/iso"

# **Membuat file autounattend.xml**
cat <<EOF > /root/autounattend.xml
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="windowsPE">
        <component name="Microsoft-Windows-International-Core-WinPE">
            <InputLocale>0409:00000409</InputLocale>
            <SystemLocale>en-US</SystemLocale>
            <UILanguage>en-US</UILanguage>
            <UserLocale>en-US</UserLocale>
        </component>
        <component name="Microsoft-Windows-Setup">
            <DiskConfiguration>
                <Disk wcm:action="add">
                    <CreatePartitions>
                        <CreatePartition wcm:action="add">
                            <Order>1</Order>
                            <Size>500</Size>
                            <Type>Primary</Type>
                        </CreatePartition>
                        <CreatePartition wcm:action="add">
                            <Order>2</Order>
                            <Extend>true</Extend>
                            <Type>Primary</Type>
                        </CreatePartition>
                    </CreatePartitions>
                    <ModifyPartitions>
                        <ModifyPartition wcm:action="add">
                            <Active>true</Active>
                            <Format>NTFS</Format>
                            <Label>System</Label>
                            <Order>1</Order>
                            <PartitionID>1</PartitionID>
                        </ModifyPartition>
                        <ModifyPartition wcm:action="add">
                            <Active>false</Active>
                            <Format>NTFS</Format>
                            <Label>Windows</Label>
                            <Order>2</Order>
                            <PartitionID>2</PartitionID>
                        </ModifyPartition>
                    </ModifyPartitions>
                    <DiskID>0</DiskID>
                    <WillWipeDisk>true</WillWipeDisk>
                </Disk>
            </DiskConfiguration>
            <ImageInstall>
                <OSImage>
                    <InstallFrom>
                        <MetaData wcm:action="add">
                            <Key>/image/index</Key>
                            <Value>1</Value>
                        </MetaData>
                    </InstallFrom>
                    <InstallTo>
                        <DiskID>0</DiskID>
                        <PartitionID>2</PartitionID>
                    </InstallTo>
                    <WillWipeDisk>true</WillWipeDisk>
                </OSImage>
            </ImageInstall>
            <UserData>
                <AcceptEula>true</AcceptEula>
                <FullName>Administrator</FullName>
                <Organization>Company</Organization>
                <ProductKey>
                    <Key>XXXXX-XXXXX-XXXXX-XXXXX-XXXXX</Key> <!-- Ganti dengan serial Windows -->
                </ProductKey>
            </UserData>
        </component>
    </settings>
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-Shell-Setup">
            <AutoLogon>
                <Username>Administrator</Username>
                <Password>
                    <Value>cGFzc3dvcmQ=</Value>
                    <PlainText>false</PlainText>
                </Password>
                <Enabled>true</Enabled>
                <LogonCount>999</LogonCount>
            </AutoLogon>
            <FirstLogonCommands>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>powershell -ExecutionPolicy Bypass -File C:\Windows\Setup\Scripts\Enable-Rdp.ps1</CommandLine>
                    <Order>1</Order>
                </SynchronousCommand>
            </FirstLogonCommands>
            <TimeZone>UTC</TimeZone>
        </component>
    </settings>
</unattend>
EOF

# **Membuat file Enable-Rdp.ps1**
cat <<EOF > /root/Enable-Rdp.ps1
# Enable Remote Desktop
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0

# Allow RDP in Firewall
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"

# Set Network Level Authentication
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name "UserAuthentication" -Value 1
EOF

# **Unduh Windows ISO**
echo "⬇️ Downloading Windows ISO..."
wget -O "$ISO_PATH" "$ISO_URL"

# **Cek apakah ISO berhasil diunduh**
if [ ! -f "$ISO_PATH" ]; then
    echo "❌ Download Windows ISO gagal."
    exit 1
fi

# **Mount ISO Windows**
mkdir -p "$TEMP_DIR"
mount -o loop "$ISO_PATH" "$TEMP_DIR"

# **Tambahkan file autounattend.xml dan Enable-Rdp.ps1 ke dalam ISO**
mkdir -p "$TEMP_DIR/Windows/Setup/Scripts"
cp "/root/autounattend.xml" "$TEMP_DIR/Sources/"
cp "/root/Enable-Rdp.ps1" "$TEMP_DIR/Windows/Setup/Scripts/"

# **Buat ISO baru dengan file tambahan**
echo "📀 Creating modified Windows ISO..."
genisoimage -o "$OUTPUT_ISO" -b boot/etfsboot.com -no-emul-boot -boot-load-size 4 -boot-info-table -R -J "$TEMP_DIR"

# **Unmount ISO**
umount "$TEMP_DIR"

# **Buat disk image untuk Windows**
echo "💾 Creating virtual disk..."
qemu-img create -f raw "$WINDOWS_IMG" 40G

# **Jalankan instalasi Windows di QEMU**
echo "🚀 Starting Windows installation..."
qemu-system-x86_64 -enable-kvm -m 4096 -cpu host -smp 2 \
    -drive file="$WINDOWS_IMG",format=raw \
    -cdrom "$OUTPUT_ISO" \
    -boot d -vnc :1 -device VGA -vga std -net nic -net user

echo "✅ Instalasi Windows dimulai. Hubungkan ke VNC di port :1 untuk memonitor proses."

