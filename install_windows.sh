#!/bin/bash

# 1️⃣ Update VPS dan Instal Dependensi
apt-get update && apt-get upgrade -y
apt-get install -y qemu-kvm qemu-utils wget curl unzip

# 2️⃣ Download Windows ISO Terbaru
ISO_URL="https://go.microsoft.com/fwlink/p/?linkid=2195587&clcid=0x409&culture=en-us&country=us"
ISO_FILE="/tmp/windows.iso"

echo "Downloading Windows ISO..."
wget -O "$ISO_FILE" "$ISO_URL"

# 3️⃣ Membuat Hard Disk Virtual untuk Windows
IMG_FILE="/tmp/windows.img"
qemu-img create -f raw "$IMG_FILE" 50G

# 4️⃣ Membuat File XML untuk Instalasi Otomatis
XML_FILE="/tmp/autounattend.xml"
cat > "$XML_FILE" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="windowsPE">
        <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <DiskConfiguration>
                <Disk wcm:action="add">
                    <CreatePartitions>
                        <CreatePartition wcm:action="add">
                            <Order>1</Order>
                            <Type>Primary</Type>
                            <Size>100</Size>
                        </CreatePartition>
                        <CreatePartition wcm:action="add">
                            <Order>2</Order>
                            <Type>Primary</Type>
                            <Extend>true</Extend>
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
                            <Letter>C</Letter>
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
            <UserData>
                <AcceptEula>true</AcceptEula>
                <FullName>Administrator</FullName>
                <Organization>Company</Organization>
            </UserData>
        </component>
    </settings>
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <AutoLogon>
                <Password>
                    <Value>cGFzc3dvcmQ=</Value>
                    <PlainText>false</PlainText>
                </Password>
                <Enabled>true</Enabled>
                <LogonCount>1</LogonCount>
                <Username>Administrator</Username>
            </AutoLogon>
            <FirstLogonCommands>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>cmd /c net user Administrator /active:yes</CommandLine>
                    <Order>1</Order>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>cmd /c netsh advfirewall set allprofiles state off</CommandLine>
                    <Order>2</Order>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>cmd /c reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AutoAdminLogon /t REG_SZ /d 1 /f</CommandLine>
                    <Order>3</Order>
                </SynchronousCommand>
            </FirstLogonCommands>
        </component>
    </settings>
</unattend>
EOF

# 5️⃣ Menjalankan Instalasi Windows di QEMU
echo "Starting Windows installation in QEMU..."
qemu-system-x86_64 -enable-kvm -m 4096 -cpu host -smp 2 \
    -drive file="$IMG_FILE",format=raw \
    -cdrom "$ISO_FILE" \
    -boot d -vnc :1 \
    -net nic -net user \
    -device usb-ehci,id=usb -device usb-tablet \
    -drive file="$XML_FILE",format=raw,if=virtio

echo "Windows installation started. Connect via VNC at port :1."

# 6️⃣ Mengatur RDP Otomatis Setelah Instalasi
RDP_SETUP="/tmp/rdp_setup.ps1"
cat > "$RDP_SETUP" <<EOF
# Enable RDP
Set-ItemProperty "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
EOF

echo "RDP setup script created."
echo "Windows installation in progress. Please wait..."

# Selesai 🚀
