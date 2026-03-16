# ============================================================
#  ForensicsTool.ps1
#  Hile kontrol kolaylastirici - Forensics Arac
#  Gelistirici: GitHub kullanicisi
#  Aciklama: Belirtilen sistem klasorlerini tek tiklama ile acar
# ============================================================

# Yonetici kontrolu - Bazi klasorler icin gerekli
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "UYARI: Bazi klasorler yonetici yetkisi gerektirebilir." -ForegroundColor Yellow
}

# WPF ve gerekli kutuphaneleri yukle
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

# ============================================================
# Tum yollar dinamik olarak hesaplaniyor - kullanici adi ve
# disk harfi otomatik aliniyor, sabit path yazilmiyor
# ============================================================

# Mevcut kullanicinin ana klasorunu al
$kullaniciProfili = [System.Environment]::GetFolderPath("UserProfile")
$appData          = [System.Environment]::GetFolderPath("ApplicationData")
$localAppData     = [System.Environment]::GetFolderPath("LocalApplicationData")

# Windows kurulu disk harfini dinamik al (genellikle C: ama olmayabilir)
$windowsDisk = $env:SystemDrive  # Ornek: "C:"
$windowsRoot = $env:SystemRoot   # Ornek: "C:\Windows"

# ============================================================
# Forensics klasor listesi - Ad ve dinamik yol eslesmesi
# ============================================================
$klasorler = @(
    [PSCustomObject]@{
        Ad   = "Son Kullanilan Dosyalar (Recent)"
        Yol  = Join-Path $kullaniciProfili "AppData\Roaming\Microsoft\Windows\Recent"
    },
    [PSCustomObject]@{
        Ad   = "Prefetch Kayitlari"
        Yol  = Join-Path $windowsRoot "Prefetch"
    },
    [PSCustomObject]@{
        Ad   = "Gecici Dosyalar (Temp)"
        Yol  = Join-Path $localAppData "Temp"
    },
    [PSCustomObject]@{
        Ad   = "Bagli Cihazlar Platformu"
        Yol  = Join-Path $localAppData "ConnectedDevicesPlatform"
    },
    [PSCustomObject]@{
        Ad   = "JumpList - Otomatik Hedefler"
        Yol  = Join-Path $appData "Microsoft\Windows\Recent\AutomaticDestinations"
    },
    [PSCustomObject]@{
        Ad   = "JumpList - Ozel Hedefler"
        Yol  = Join-Path $appData "Microsoft\Windows\Recent\CustomDestinations"
    },
    [PSCustomObject]@{
        Ad   = "Baslangic Programlari (Startup)"
        Yol  = Join-Path $appData "Microsoft\Windows\Start Menu\Programs\Startup"
    },
    [PSCustomObject]@{
        Ad   = "Arama Dizini Konumlari"
        Yol  = Join-Path $kullaniciProfili "Searches"
    },
    [PSCustomObject]@{
        Ad   = "Sistem Suruculeri (Drivers)"
        Yol  = Join-Path $windowsRoot "System32\drivers"
    },
    [PSCustomObject]@{
        Ad   = "Olay Gunlukleri (Event Logs)"
        Yol  = Join-Path $windowsRoot "System32\Winevt\Logs"
    }
)

# ============================================================
# WPF XAML arayuzu - ImGui esinlenmeli, sade ve modern tasarim
# Renk paleti: Koyu arkaplan + Mavi-gri vurgular + Beyaz metin
# ============================================================
[xml]$xaml = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="Forensics Tool - Hile Kontrol Araci"
    Width="820"
    Height="580"
    MinWidth="620"
    MinHeight="400"
    WindowStartupLocation="CenterScreen"
    Background="#1A1D23"
    FontFamily="Segoe UI">

    <Window.Resources>

        <!-- Ana buton stili - mavi vurgu -->
        <Style x:Key="AcButon" TargetType="Button">
            <Setter Property="Background"    Value="#2D6BE4"/>
            <Setter Property="Foreground"    Value="#FFFFFF"/>
            <Setter Property="FontSize"      Value="12"/>
            <Setter Property="FontWeight"    Value="SemiBold"/>
            <Setter Property="Padding"       Value="18,0"/>
            <Setter Property="Height"        Value="34"/>
            <Setter Property="MinWidth"      Value="70"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Cursor"        Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="kk"
                                Background="{TemplateBinding Background}"
                                CornerRadius="6"
                                Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center"
                                              VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="kk" Property="Background" Value="#3D7BF4"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="kk" Property="Background" Value="#1D5BD4"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="kk" Property="Background" Value="#3A3F4B"/>
                                <Setter Property="Foreground" Value="#666B75"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Kopyala butonu - daha sade, ikincil eylem -->
        <Style x:Key="KopyalaButon" TargetType="Button">
            <Setter Property="Background"    Value="#2A2E38"/>
            <Setter Property="Foreground"    Value="#9BA3B2"/>
            <Setter Property="FontSize"      Value="11"/>
            <Setter Property="Padding"       Value="10,0"/>
            <Setter Property="Height"        Value="34"/>
            <Setter Property="MinWidth"      Value="38"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="BorderBrush"   Value="#3A3F4B"/>
            <Setter Property="Cursor"        Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="kb"
                                Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="6"
                                Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center"
                                              VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="kb" Property="Background" Value="#353A47"/>
                                <Setter Property="Foreground"                 Value="#C8CFD8"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="kb" Property="Background" Value="#1E2229"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ScrollBar ozel stili - ince ve sade -->
        <Style TargetType="ScrollBar">
            <Setter Property="Width"      Value="8"/>
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ScrollBar">
                        <Grid>
                            <Track x:Name="PART_Track" IsDirectionReversed="True">
                                <Track.Thumb>
                                    <Thumb>
                                        <Thumb.Template>
                                            <ControlTemplate TargetType="Thumb">
                                                <Border Background="#3D4251"
                                                        CornerRadius="4"
                                                        Margin="2,0"/>
                                            </ControlTemplate>
                                        </Thumb.Template>
                                    </Thumb>
                                </Track.Thumb>
                            </Track>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

    </Window.Resources>

    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="56"/>   <!-- Baslik alani -->
            <RowDefinition Height="*"/>    <!-- Scrollable icerik -->
            <RowDefinition Height="40"/>   <!-- Alt durum cubugu -->
        </Grid.RowDefinitions>

        <!-- ===== BASLIK PANELI ===== -->
        <Border Grid.Row="0"
                Background="#21242D"
                BorderBrush="#2D3140"
                BorderThickness="0,0,0,1"
                Padding="24,0">
            <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                <!-- Forensics simgesi -->
                <Border Background="#2D6BE4"
                        CornerRadius="6"
                        Width="28" Height="28"
                        Margin="0,0,12,0">
                    <TextBlock Text="F"
                               Foreground="White"
                               FontSize="14"
                               FontWeight="Bold"
                               HorizontalAlignment="Center"
                               VerticalAlignment="Center"/>
                </Border>

                <StackPanel VerticalAlignment="Center">
                    <TextBlock Text="Forensics Tool"
                               Foreground="#E8ECF4"
                               FontSize="15"
                               FontWeight="SemiBold"/>
                    <TextBlock Text="Hile Kontrol Araci - Sistem Klasorleri"
                               Foreground="#5A6070"
                               FontSize="11"/>
                </StackPanel>

                <!-- Kullanici bilgisi sag taraf -->
                <TextBlock x:Name="kullaniciBilgi"
                           Foreground="#4A5060"
                           FontSize="11"
                           VerticalAlignment="Center"
                           HorizontalAlignment="Right"
                           Margin="0"/>
            </StackPanel>
        </Border>

        <!-- ===== SCROLLABLE LISTE ALANI ===== -->
        <ScrollViewer Grid.Row="1"
                      VerticalScrollBarVisibility="Auto"
                      HorizontalScrollBarVisibility="Disabled"
                      Padding="24,16,16,16"
                      Background="#1A1D23">
            <StackPanel x:Name="anaPanel" Spacing="6"/>
        </ScrollViewer>

        <!-- ===== ALT DURUM CUBUGU ===== -->
        <Border Grid.Row="2"
                Background="#21242D"
                BorderBrush="#2D3140"
                BorderThickness="0,1,0,0"
                Padding="24,0">
            <Grid>
                <TextBlock x:Name="durumMetni"
                           Text="Hazir - Bir klasor secin"
                           Foreground="#4A5060"
                           FontSize="11"
                           VerticalAlignment="Center"/>
                <TextBlock x:Name="sayacMetni"
                           Foreground="#4A5060"
                           FontSize="11"
                           VerticalAlignment="Center"
                           HorizontalAlignment="Right"/>
            </Grid>
        </Border>

    </Grid>
</Window>
"@

# ============================================================
# XAML'i yukle ve pencereyi olustur
# ============================================================
$reader  = New-Object System.Xml.XmlNodeReader $xaml
$pencere = [Windows.Markup.XamlReader]::Load($reader)

# Kontrolleri degiskenlere bagla
$anaPanel      = $pencere.FindName("anaPanel")
$durumMetni    = $pencere.FindName("durumMetni")
$sayacMetni    = $pencere.FindName("sayacMetni")
$kullaniciBilgi = $pencere.FindName("kullaniciBilgi")

# Kullanici adini goster
$kullaniciBilgi.Text = "Kullanici: $env:USERNAME"

# Sayac guncelle
$sayacMetni.Text = "$($klasorler.Count) klasor yuklendi"

# ============================================================
# Klasor satiri olusturma fonksiyonu
# Her klasor icin bir satir: sol=bilgi, sag=butonlar
# ============================================================
function Yeni-KlasorSatiri {
    param($KlasorBilgisi, $Index)

    # Satir ana karti
    $kart = New-Object System.Windows.Controls.Border
    $kart.Background         = if ($Index % 2 -eq 0) { "#21242D" } else { "#1E2229" }
    $kart.CornerRadius       = "8"
    $kart.BorderBrush        = "#2D3140"
    $kart.BorderThickness    = "1"
    $kart.Padding            = "16,12"
    $kart.Margin             = "0,0,8,0"

    # Hover efekti icin mouse olaylari
    $kart.Add_MouseEnter({
        param($kaynak, $e)
        $kaynak.Background = "#262A35"
        $kaynak.BorderBrush = "#3D6BE0"
    })
    $kart.Add_MouseLeave({
        param($kaynak, $e)
        $kaynak.Background = if ($Index % 2 -eq 0) { "#21242D" } else { "#1E2229" }
        $kaynak.BorderBrush = "#2D3140"
    })

    # Ic grid: sol bilgi, sag butonlar
    $ic = New-Object System.Windows.Controls.Grid
    $solSutun  = New-Object System.Windows.Controls.ColumnDefinition
    $solSutun.Width = "*"
    $sagSutun  = New-Object System.Windows.Controls.ColumnDefinition
    $sagSutun.Width = "Auto"
    $ic.ColumnDefinitions.Add($solSutun)
    $ic.ColumnDefinitions.Add($sagSutun)

    # === SOL TARAF: Klasor adi + yol ===
    $solPanel = New-Object System.Windows.Controls.StackPanel
    $solPanel.VerticalAlignment = "Center"
    $solPanel.Margin = "0,0,16,0"

    # Klasor adi (buyuk, belirgin)
    $adMetni = New-Object System.Windows.Controls.TextBlock
    $adMetni.Text       = $KlasorBilgisi.Ad
    $adMetni.Foreground = "#D0D6E0"
    $adMetni.FontSize   = 13
    $adMetni.FontWeight = "Medium"
    $adMetni.TextTrimming = "CharacterEllipsis"

    # Yol metni (kucuk, soluk)
    $yolMetni = New-Object System.Windows.Controls.TextBlock
    $yolMetni.Text       = $KlasorBilgisi.Yol
    $yolMetni.Foreground = "#4A5060"
    $yolMetni.FontSize   = 11
    $yolMetni.FontFamily = "Consolas"
    $yolMetni.Margin     = "0,3,0,0"
    $yolMetni.TextTrimming = "CharacterEllipsis"

    # Klasor varlik durumu rozeti
    $rozetPanel = New-Object System.Windows.Controls.StackPanel
    $rozetPanel.Orientation = "Horizontal"
    $rozetPanel.Margin = "0,5,0,0"

    $rozet = New-Object System.Windows.Controls.Border
    $rozet.CornerRadius = "4"
    $rozet.Padding = "8,2"

    $rozetMetni = New-Object System.Windows.Controls.TextBlock
    $rozetMetni.FontSize   = 10
    $rozetMetni.FontWeight = "Medium"

    # Klasor var mi kontrol et
    if (Test-Path $KlasorBilgisi.Yol) {
        $rozet.Background     = "#1A3A1A"
        $rozet.BorderBrush    = "#2D6B2D"
        $rozet.BorderThickness = "1"
        $rozetMetni.Text       = "Mevcut"
        $rozetMetni.Foreground = "#4CAF50"
    } else {
        $rozet.Background     = "#3A1A1A"
        $rozet.BorderBrush    = "#6B2D2D"
        $rozet.BorderThickness = "1"
        $rozetMetni.Text       = "Bulunamadi"
        $rozetMetni.Foreground = "#EF5350"
    }

    $rozet.Child = $rozetMetni
    $rozetPanel.Children.Add($rozet) | Out-Null
    $solPanel.Children.Add($adMetni)   | Out-Null
    $solPanel.Children.Add($yolMetni)  | Out-Null
    $solPanel.Children.Add($rozetPanel) | Out-Null

    # === SAG TARAF: Butonlar ===
    $sagPanel = New-Object System.Windows.Controls.StackPanel
    $sagPanel.Orientation       = "Horizontal"
    $sagPanel.VerticalAlignment = "Center"
    $sagPanel.Margin            = "0"

    # "Kopyala" butonu - yolu panoya kopyalar
    $kopyalaButon = New-Object System.Windows.Controls.Button
    $kopyalaButon.Content = "📋"
    $kopyalaButon.Style   = $pencere.Resources["KopyalaButon"]
    $kopyalaButon.ToolTip = "Yolu Kopyala"
    $kopyalaButon.Margin  = "0,0,8,0"
    $kopyalaButon.Tag     = $KlasorBilgisi.Yol

    # Kopyala buton olayi
    $kopyalaButon.Add_Click({
        param($kaynak, $e)
        try {
            [System.Windows.Clipboard]::SetText($kaynak.Tag)
            $durumMetni.Text       = "Kopyalandi: $($kaynak.Tag)"
            $durumMetni.Foreground = "#4CAF50"
            # 2 saniye sonra durum metnini sifirla
            $zamanlayici = New-Object System.Windows.Threading.DispatcherTimer
            $zamanlayici.Interval = [TimeSpan]::FromSeconds(2)
            $zamanlayici.Add_Tick({
                $durumMetni.Text       = "Hazir - Bir klasor secin"
                $durumMetni.Foreground = "#4A5060"
                $zamanlayici.Stop()
            })
            $zamanlayici.Start()
        } catch {
            $durumMetni.Text       = "Kopyalama basarisiz"
            $durumMetni.Foreground = "#EF5350"
        }
    })

    # "Ac" butonu - klasoru Explorer'da acar
    $acButon = New-Object System.Windows.Controls.Button
    $acButon.Content = "  Ac  "
    $acButon.Style   = $pencere.Resources["AcButon"]
    $acButon.Tag     = $KlasorBilgisi.Yol
    $acButon.ToolTip = "Explorer'da Ac"

    # Ac buton olayi
    $acButon.Add_Click({
        param($kaynak, $e)
        $hedefYol = $kaynak.Tag
        try {
            if (Test-Path $hedefYol) {
                # Klasor mevcutsa direkt ac
                Start-Process "explorer.exe" -ArgumentList "`"$hedefYol`""
                $durumMetni.Text       = "Acildi: $hedefYol"
                $durumMetni.Foreground = "#4CAF50"
            } else {
                # Klasor yoksa ust dizini ac, yoksa hata goster
                $ustDizin = Split-Path $hedefYol -Parent
                if (Test-Path $ustDizin) {
                    Start-Process "explorer.exe" -ArgumentList "`"$ustDizin`""
                    $durumMetni.Text       = "Klasor bulunamadi, ust dizin acildi: $ustDizin"
                    $durumMetni.Foreground = "#FF9800"
                } else {
                    $durumMetni.Text       = "Hata: Klasor ve ust dizin bulunamadi - $hedefYol"
                    $durumMetni.Foreground = "#EF5350"
                    [System.Windows.MessageBox]::Show(
                        "Bu klasor mevcut degil:`n$hedefYol",
                        "Klasor Bulunamadi",
                        [System.Windows.MessageBoxButton]::OK,
                        [System.Windows.MessageBoxImage]::Warning
                    ) | Out-Null
                }
            }
        } catch {
            $durumMetni.Text       = "Hata: $($_.Exception.Message)"
            $durumMetni.Foreground = "#EF5350"
        }
    })

    $sagPanel.Children.Add($kopyalaButon) | Out-Null
    $sagPanel.Children.Add($acButon)      | Out-Null

    # Gridi birlestirir
    [System.Windows.Controls.Grid]::SetColumn($solPanel, 0)
    [System.Windows.Controls.Grid]::SetColumn($sagPanel, 1)
    $ic.Children.Add($solPanel) | Out-Null
    $ic.Children.Add($sagPanel) | Out-Null

    $kart.Child = $ic
    return $kart
}

# ============================================================
# Tum klasor satirlarini listeye ekle
# ============================================================
for ($i = 0; $i -lt $klasorler.Count; $i++) {
    $satir = Yeni-KlasorSatiri -KlasorBilgisi $klasorler[$i] -Index $i
    $anaPanel.Children.Add($satir) | Out-Null
}

# ============================================================
# Pencereyi goster
# ============================================================
$pencere.ShowDialog() | Out-Null
