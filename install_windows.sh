#!/bin/bash

# Pastikan script dijalankan sebagai root
if [[ $EUID -ne 0 ]]; then
    echo "Silakan jalankan script ini dengan sudo!"
    exit 1
fi

echo "Menginstal QEMU dan dependensi..."
sudo apt-get update
sudo apt-get install -y qemu-kvm qemu-utils qemu-system-x86 wget curl genisoimage || { echo "Gagal menginstal QEMU!"; exit 1; }
echo "QEMU berhasil diinstal."

# Set parameter instalasi
IMG_FILE="windows.img"
ISO_FILE="windows.iso"
ISO_LINK="https://go.microsoft.com/fwlink/p/?linkid=2195333"
VIRTIO_ISO="virtio-win.iso"
VIRTIO_LINK="https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/latest-virtio/virtio-win.iso"
UNATTENDED_ISO="autounattend.iso"

# Ukuran disk bisa dikustomisasi (default 40GB)
IMG_SIZE=${1:-40G}

echo "Membuat file image $IMG_FILE dengan ukuran $IMG_SIZE..."
qemu-img create -f raw "$IMG_FILE" "$IMG_SIZE" || { echo "Gagal membuat image file!"; exit 1; }
echo "File image $IMG_FILE berhasil dibuat."

# Download Windows ISO
echo "Mengunduh Windows ISO dari Microsoft..."
wget -O "$ISO_FILE" "$ISO_LINK" || { echo "Gagal mengunduh Windows ISO!"; exit 1; }
echo "Windows ISO berhasil diunduh."

# Download VirtIO Drivers
echo "Mengunduh VirtIO Drivers..."
wget -O "$VIRTIO_ISO" "$VIRTIO_LINK" || { echo "Gagal mengunduh VirtIO drivers!"; exit 1; }
echo "VirtIO Drivers berhasil diunduh."

# Membuat AutoUnattend.xml untuk instalasi otomatis
echo "Membuat file AutoUnattend.xml untuk instalasi otomatis..."
cat > AutoUnattend.xml <<EOF
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="windowsPE">
        <component name="Microsoft-Windows-Setup" processorArchitecture="x86" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <UserData>
                <ProductKey>
                    <Key></Key>
                    <WillShowUI>Never</WillShowUI>
                </ProductKey>
                <AcceptEula>true</AcceptEula>
                <FullName>Administrator</FullName>
                <Organization>MyCompany</Organization>
            </UserData>
            <ImageInstall>
                <OSImage>
                    <InstallFrom>
                        <MetaData wcm:action="add">
                            <Key>/Image/Index</Key>
                            <Value>1</Value>
                        </MetaData>
                    </InstallFrom>
                    <InstallTo>
                        <DiskID>0</DiskID>
                        <PartitionID>1</PartitionID>
                    </InstallTo>
                </OSImage>
            </ImageInstall>
        </component>
    </settings>
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="x86" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <AutoLogon>
                <Enabled>true</Enabled>
                <Username>Administrator</Username>
            </AutoLogon>
            <UserAccounts>
                <AdministratorPassword>
                    <Value>Password123!</Value>
                    <PlainText>true</PlainText>
                </AdministratorPassword>
            </UserAccounts>
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
                <NetworkLocation>Work</NetworkLocation>
                <SkipUserOOBE>true</SkipUserOOBE>
                <SkipMachineOOBE>true</SkipMachineOOBE>
            </OOBE>
            <RegisteredOrganization>MyCompany</RegisteredOrganization>
            <RegisteredOwner>Administrator</RegisteredOwner>
        </component>
    </settings>
    <settings pass="specialize">
        <component name="Microsoft-Windows-TerminalServices-LocalSessionManager" processorArchitecture="x86" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <fDenyTSConnections>false</fDenyTSConnections>
        </component>
    </settings>
</unattend>
EOF

echo "AutoUnattend.xml berhasil dibuat."

# Membuat ISO untuk file AutoUnattend.xml
echo "Membuat ISO untuk AutoUnattend.xml..."
genisoimage -o "$UNATTENDED_ISO" -J -r AutoUnattend.xml || { echo "Gagal membuat autounattend ISO!"; exit 1; }
echo "ISO AutoUnattend berhasil dibuat."

# Menjalankan QEMU untuk instalasi Windows
echo "Memulai instalasi Windows di QEMU secara otomatis..."
qemu-system-x86_64 -enable-kvm -m 4096 -cpu host -smp 2 \
    -drive file="$IMG_FILE",format=raw \
    -cdrom "$ISO_FILE" -boot d \
    -drive file="$VIRTIO_ISO",media=cdrom \
    -drive file="$UNATTENDED_ISO",media=cdrom \
    -vga qxl \
    -display vnc=:1 \
    -netdev user,id=network0 -device virtio-net,netdev=network0 \
    -device usb-tablet

echo "Windows sedang diinstal secara otomatis. Gunakan VNC untuk mengaksesnya (port :1)."

# Menunggu proses instalasi selesai dan reboot
echo "Menunggu 10 menit agar instalasi selesai..."
sleep 600

# Menjalankan kembali Windows dari disk
echo "Menjalankan kembali Windows setelah instalasi..."
qemu-system-x86_64 -enable-kvm -m 4096 -cpu host -smp 2 \
    -drive file="$IMG_FILE",format=raw \
    -vga qxl \
    -display vnc=:1 \
    -netdev user,id=network0 -device virtio-net,netdev=network0 \
    -device usb-tablet \
    -redir tcp:3389::3389

echo "Windows sudah berjalan dengan RDP aktif. Gunakan Remote Desktop untuk mengaksesnya dengan IP_VPS:3389."
