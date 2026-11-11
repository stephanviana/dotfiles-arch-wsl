@{
    Apps = @{
        Winget = @{
            Bitwarden = 'Bitwarden.Bitwarden'
            IntelliJ = 'JetBrains.IntelliJIDEA'
            VCRedist = 'abbodi1406.vcredist'
            IntelDSA = 'Intel.IntelDriverAndSupportAssistant'
            WinRAR = 'RARLab.WinRAR'
            SevenZip = '7zip.7zip'
            VLC = 'VideoLAN.VLC'
            PlatformTools = 'Google.PlatformTools'
            YouTubeMusic = 'Ytmdesktop.Ytmdesktop'
        }
        NvidiaControlPanelStoreId = '9NF8H0H7WMLT'
        NvidiaAppStoreId = 'XP8CLZL93F5Z4P'
        # The official installer rejects this model with CheckIfGPUIsSupported.
        NvidiaAppUnsupportedModels = @('NVIDIA GeForce MX110')
    }
    Desktop = @{
        NodeMinimum = '20.19.0'
        Winget = @{
            VSCode = 'Microsoft.VisualStudioCode'
            Node = 'OpenJS.NodeJS.LTS'
            WebView2 = 'Microsoft.EdgeWebView2Runtime'
            OhMyPosh = 'JanDeDobbeleer.OhMyPosh'
            Starship = 'Starship.Starship'
            WindowsTerminal = 'Microsoft.WindowsTerminal'
        }
    }
}
