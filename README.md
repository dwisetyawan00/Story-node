# 🚀 Tutorial Install Node Story

![Banner](https://files.readme.io/3e11869-header_story.png)

## 💻 Spesifikasi Minimum

| Komponen | Minimal | Direkomendasikan |
|----------|---------|------------------|
| CPU | 4 Core | 8 Core |
| RAM | 8 GB | 16 GB |
| Penyimpanan | 100 GB SSD | 500 TB SSD |
| Koneksi Internet | 10 Mbps | 100 Mbps |
| OS | Ubuntu 20.04 LTS | Ubuntu 22.04 LTS |
| Port | 30303, 8545 | 30303, 8545, 8546 |


Selamat datang di tutorial instalasi Node Story. Tutorial ini akan membantumu untuk setup node Story dengan mudah dan cepat. Mari kita mulai! 

## ⚡ Cara Install Satset

Jalankan script auto-install ini:
```bash
curl -s https://raw.githubusercontent.com/dwisetyawan00/Story-node/main/install-story.sh | bash
```

## 📝 Perintah lainnya ( jika dibutuhkan )

### Cek Log
Mau ngintip apa yang terjadi di balik layar? Gunakan perintah ini:

**Untuk Story Client:**
```bash
# Cara 1
sudo journalctl -u story -f -n 100

# Cara 2
sudo journalctl -fu story
```

**Untuk Story-Geth:**
```bash
# Cara 1
sudo journalctl -u story-geth -f -n 100

# Cara 2
sudo journalctl -fu story-geth
```

### Mengelola Layanan

**Menghentikan Layanan:**
```bash
sudo systemctl stop story
sudo systemctl stop story-geth
```

**Menjalankan Layanan:**
```bash
sudo systemctl start story
sudo systemctl start story-geth
```

**Mulai Ulang Layanan:**
```bash
sudo systemctl restart story
sudo systemctl restart story-geth
```

**Mengecek Status:**
```bash
sudo systemctl status story
sudo systemctl status story-geth
```

## 💡 Tips
- Selalu cek status node secara berkala
- Simpan perintah-perintah di atas agar mudah diakses
- Jika mengalami masalah, cek log untuk troubleshooting
