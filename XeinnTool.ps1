# ============================================================
#  ForensicsTool.ps1
#  Hile kontrol kolaylastirici - Forensics Arac
#  Aciklama: Belirtilen sistem klasorlerini tek tiklama ile acar
# ============================================================

# WPF kutuphanelerini yukle
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# ============================================================
# Dinamik yol hesaplama - hic bir yerde sabit kullanici adi yok
# ============================================================
$kullaniciProfili = [System.Environment]::GetFolderPath("UserProfile")
$appData          = [System.Environment]::GetFolderPath("ApplicationData")
$localAppData     = [System.Environment]::GetFolderPath("LocalApplicationData")
$windowsRoot      = $env:SystemRoot

# ============================================================
# Forensics klasor listesi
# ============================================================
$klasorler = @(
    [PSCustomObject]@{ Ad = "Son Kullanilan Dosyalar (Recent)";    Yol = Join-Path $kullaniciProfili "AppData\Roaming\Microsoft\Windows\Recent" },
    [PSCustomObject]@{ Ad = "Prefetch Kayitlari";                  Yol = Join-Path $windowsRoot "Prefetch" },
    [PSCustomObject]@{ Ad = "Gecici Dosyalar (Temp)";              Yol = Join-Path $localAppData "Temp" },
    [PSCustomObject]@{ Ad = "Bagli Cihazlar Platformu";            Yol = Join-Path $localAppData "ConnectedDevicesPlatform" },
    [PSCustomObject]@{ Ad = "JumpList - Otomatik Hedefler";        Yol = Join-Path $appData "Microsoft\Windows\Recent\AutomaticDestinations" },
    [PSCustomObject]@{ Ad = "JumpList - Ozel Hedefler";            Yol = Join-Path $appData "Microsoft\Windows\Recent\CustomDestinations" },
    [PSCustomObject]@{ Ad = "Baslangic Programlari (Startup)";     Yol = Join-Path $appData "Microsoft\Windows\Start Menu\Programs\Startup" },
    [PSCustomObject]@{ Ad = "Arama Dizini Konumlari";              Yol = Join-Path $kullaniciProfili "Searches" },
    [PSCustomObject]@{ Ad = "Sistem Suruculeri (Drivers)";         Yol = Join-Path $windowsRoot "System32\drivers" },
    [PSCustomObject]@{ Ad = "Olay Gunlukleri (Event Logs)";        Yol = Join-Path $windowsRoot "System32\Winevt\Logs" }
)

# ============================================================
# WPF XAML - Spacing kaldirildi (WPF desteklemiyor),
# emoji kaldirildi (encoding sorunu), Margin ile aralik verildi
# ============================================================
[xml]$xaml = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="Xeinn Tool - Hile Kontrol Araci"
    Width="820" Height="580"
    MinWidth="620" MinHeight="400"
    WindowStartupLocation="CenterScreen"
    Background="#1A1D23"
    FontFamily="Segoe UI">

    <Window.Resources>

        <Style x:Key="AcButon" TargetType="Button">
            <Setter Property="Background"      Value="#2D6BE4"/>
            <Setter Property="Foreground"      Value="#FFFFFF"/>
            <Setter Property="FontSize"        Value="12"/>
            <Setter Property="FontWeight"      Value="SemiBold"/>
            <Setter Property="Padding"         Value="18,0"/>
            <Setter Property="Height"          Value="34"/>
            <Setter Property="MinWidth"        Value="70"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Cursor"          Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="bg" Background="{TemplateBinding Background}" CornerRadius="6" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="bg" Property="Background" Value="#3D7BF4"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="bg" Property="Background" Value="#1D5BD4"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="KopyalaButon" TargetType="Button">
            <Setter Property="Background"      Value="#2A2E38"/>
            <Setter Property="Foreground"      Value="#9BA3B2"/>
            <Setter Property="FontSize"        Value="11"/>
            <Setter Property="Padding"         Value="10,0"/>
            <Setter Property="Height"          Value="34"/>
            <Setter Property="MinWidth"        Value="70"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="BorderBrush"     Value="#3A3F4B"/>
            <Setter Property="Cursor"          Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="bg2" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="6" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="bg2" Property="Background" Value="#353A47"/>
                                <Setter Property="Foreground" Value="#C8CFD8"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="bg2" Property="Background" Value="#1E2229"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

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
                                                <Border Background="#3D4251" CornerRadius="4" Margin="2,0"/>
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
            <RowDefinition Height="56"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="40"/>
        </Grid.RowDefinitions>

        <Border Grid.Row="0" Background="#21242D" BorderBrush="#2D3140" BorderThickness="0,0,0,1" Padding="24,0">
            <Grid>
                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                    <Border Background="#2D6BE4" CornerRadius="6" Width="28" Height="28" Margin="0,0,12,0">
                        <TextBlock Text="F" Foreground="White" FontSize="14" FontWeight="Bold"
                                   HorizontalAlignment="Center" VerticalAlignment="Center"/>
                    </Border>
                    <StackPanel VerticalAlignment="Center">
                        <TextBlock Text="Xeinn Tool" Foreground="#E8ECF4" FontSize="15" FontWeight="SemiBold"/>
                        <TextBlock Text="Hile Kontrol Araci - Sistem Klasorleri" Foreground="#5A6070" FontSize="11"/>
                    </StackPanel>
                </StackPanel>
                <TextBlock x:Name="kullaniciBilgi" Foreground="#4A5060" FontSize="11"
                           VerticalAlignment="Center" HorizontalAlignment="Right" Margin="0,0,8,0"/>
            </Grid>
        </Border>

        <ScrollViewer Grid.Row="1"
                      VerticalScrollBarVisibility="Auto"
                      HorizontalScrollBarVisibility="Disabled"
                      Padding="24,16,16,16"
                      Background="#1A1D23">
            <StackPanel x:Name="anaPanel"/>
        </ScrollViewer>

        <Border Grid.Row="2" Background="#21242D" BorderBrush="#2D3140" BorderThickness="0,1,0,0" Padding="24,0">
            <Grid>
                <TextBlock x:Name="durumMetni" Text="Hazir - Bir klasor secin"
                           Foreground="#4A5060" FontSize="11" VerticalAlignment="Center"/>
                <TextBlock x:Name="sayacMetni" Foreground="#4A5060" FontSize="11"
                           VerticalAlignment="Center" HorizontalAlignment="Right"/>
            </Grid>
        </Border>
    </Grid>
</Window>
"@

# ============================================================
# Pencereyi olustur
# ============================================================
$reader  = New-Object System.Xml.XmlNodeReader $xaml
$pencere = [Windows.Markup.XamlReader]::Load($reader)

$anaPanel       = $pencere.FindName("anaPanel")
$durumMetni     = $pencere.FindName("durumMetni")
$sayacMetni     = $pencere.FindName("sayacMetni")
$kullaniciBilgi = $pencere.FindName("kullaniciBilgi")

$kullaniciBilgi.Text = "Kullanici: $env:USERNAME"
$sayacMetni.Text     = "$($klasorler.Count) klasor yuklendi"

# ============================================================
# Her klasor icin bir satir olustur
# ============================================================
function Yeni-KlasorSatiri {
    param($KlasorBilgisi, $Index)

    $bgRenk = if ($Index % 2 -eq 0) { "#21242D" } else { "#1E2229" }

    $kart = New-Object System.Windows.Controls.Border
    $kart.Background      = $bgRenk
    $kart.CornerRadius    = "8"
    $kart.BorderBrush     = "#2D3140"
    $kart.BorderThickness = "1"
    $kart.Padding         = "16,12"
    $kart.Margin          = "0,0,8,6"

    # Hover renk degisimi icin closure ile deger yakala
    $bgKaydedildi = $bgRenk
    $kart.Add_MouseEnter({ param($s,$e); $s.Background = "#262A35"; $s.BorderBrush = "#3D6BE0" })
    $kart.Add_MouseLeave([System.Windows.Input.MouseEventHandler]{
        param($s,$e)
        $s.Background = $script:bgKaydedildi
        $s.BorderBrush = "#2D3140"
    })
    $script:bgKaydedildi = $bgRenk

    # Ic grid: sol ve sag sutun
    $ic = New-Object System.Windows.Controls.Grid
    $c0 = New-Object System.Windows.Controls.ColumnDefinition; $c0.Width = "*"
    $c1 = New-Object System.Windows.Controls.ColumnDefinition; $c1.Width = "Auto"
    $ic.ColumnDefinitions.Add($c0)
    $ic.ColumnDefinitions.Add($c1)

    # === SOL PANEL ===
    $solPanel = New-Object System.Windows.Controls.StackPanel
    $solPanel.VerticalAlignment = "Center"
    $solPanel.Margin = "0,0,16,0"

    $adMetni = New-Object System.Windows.Controls.TextBlock
    $adMetni.Text         = $KlasorBilgisi.Ad
    $adMetni.Foreground   = "#D0D6E0"
    $adMetni.FontSize     = 13
    $adMetni.FontWeight   = "Medium"
    $adMetni.TextTrimming = "CharacterEllipsis"

    $yolMetni = New-Object System.Windows.Controls.TextBlock
    $yolMetni.Text         = $KlasorBilgisi.Yol
    $yolMetni.Foreground   = "#4A5060"
    $yolMetni.FontSize     = 11
    $yolMetni.FontFamily   = "Consolas"
    $yolMetni.Margin       = "0,3,0,0"
    $yolMetni.TextTrimming = "CharacterEllipsis"

    # Varlik rozeti
    $rozetPanel = New-Object System.Windows.Controls.StackPanel
    $rozetPanel.Orientation = "Horizontal"
    $rozetPanel.Margin = "0,5,0,0"

    $rozet = New-Object System.Windows.Controls.Border
    $rozet.CornerRadius    = "4"
    $rozet.Padding         = "8,2"
    $rozet.BorderThickness = "1"

    $rozetMetni = New-Object System.Windows.Controls.TextBlock
    $rozetMetni.FontSize   = 10
    $rozetMetni.FontWeight = "Medium"

    if (Test-Path $KlasorBilgisi.Yol) {
        $rozet.Background      = "#1A3A1A"
        $rozet.BorderBrush     = "#2D6B2D"
        $rozetMetni.Text       = "Mevcut"
        $rozetMetni.Foreground = "#4CAF50"
    } else {
        $rozet.Background      = "#3A1A1A"
        $rozet.BorderBrush     = "#6B2D2D"
        $rozetMetni.Text       = "Bulunamadi"
        $rozetMetni.Foreground = "#EF5350"
    }

    $rozet.Child = $rozetMetni
    $rozetPanel.Children.Add($rozet) | Out-Null
    $solPanel.Children.Add($adMetni)    | Out-Null
    $solPanel.Children.Add($yolMetni)   | Out-Null
    $solPanel.Children.Add($rozetPanel) | Out-Null

    # === SAG PANEL: Butonlar ===
    $sagPanel = New-Object System.Windows.Controls.StackPanel
    $sagPanel.Orientation       = "Horizontal"
    $sagPanel.VerticalAlignment = "Center"

    # Kopyala butonu - emoji yok
    $kopyalaButon = New-Object System.Windows.Controls.Button
    $kopyalaButon.Content = "Kopyala"
    $kopyalaButon.Style   = $pencere.Resources["KopyalaButon"]
    $kopyalaButon.ToolTip = "Yolu Panoya Kopyala"
    $kopyalaButon.Margin  = "0,0,8,0"
    $kopyalaButon.Tag     = $KlasorBilgisi.Yol

    $kopyalaButon.Add_Click({
        param($s, $e)
        try {
            [System.Windows.Clipboard]::SetText($s.Tag)
            $durumMetni.Text       = "Kopyalandi: $($s.Tag)"
            $durumMetni.Foreground = "#4CAF50"
            $t = New-Object System.Windows.Threading.DispatcherTimer
            $t.Interval = [TimeSpan]::FromSeconds(2)
            $t.Add_Tick({
                $durumMetni.Text       = "Hazir - Bir klasor secin"
                $durumMetni.Foreground = "#4A5060"
                $t.Stop()
            })
            $t.Start()
        } catch {
            $durumMetni.Text       = "Kopyalama basarisiz"
            $durumMetni.Foreground = "#EF5350"
        }
    })

    # Ac butonu
    $acButon = New-Object System.Windows.Controls.Button
    $acButon.Content = "  Ac  "
    $acButon.Style   = $pencere.Resources["AcButon"]
    $acButon.ToolTip = "Explorer'da Ac"
    $acButon.Tag     = $KlasorBilgisi.Yol

    $acButon.Add_Click({
        param($s, $e)
        $hedef = $s.Tag
        try {
            if (Test-Path $hedef) {
                Start-Process "explorer.exe" -ArgumentList "`"$hedef`""
                $durumMetni.Text       = "Acildi: $hedef"
                $durumMetni.Foreground = "#4CAF50"
            } else {
                $ust = Split-Path $hedef -Parent
                if ($ust -and (Test-Path $ust)) {
                    Start-Process "explorer.exe" -ArgumentList "`"$ust`""
                    $durumMetni.Text       = "Klasor yok, ust dizin acildi: $ust"
                    $durumMetni.Foreground = "#FF9800"
                } else {
                    $durumMetni.Text       = "Hata: Yol bulunamadi - $hedef"
                    $durumMetni.Foreground = "#EF5350"
                    [System.Windows.MessageBox]::Show(
                        "Klasor mevcut degil:`n$hedef",
                        "Bulunamadi",
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

    [System.Windows.Controls.Grid]::SetColumn($solPanel, 0)
    [System.Windows.Controls.Grid]::SetColumn($sagPanel, 1)
    $ic.Children.Add($solPanel) | Out-Null
    $ic.Children.Add($sagPanel) | Out-Null

    $kart.Child = $ic
    return $kart
}

# ============================================================
# Tum satirlari listeye ekle
# ============================================================
for ($i = 0; $i -lt $klasorler.Count; $i++) {
    $satir = Yeni-KlasorSatiri -KlasorBilgisi $klasorler[$i] -Index $i
    $anaPanel.Children.Add($satir) | Out-Null
}

# ============================================================
# Pencereyi goster
# ============================================================
$pencere.ShowDialog() | Out-Null
