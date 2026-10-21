@{
    Apps = @{
        Winget = @{
            Bitwarden = 'Bitwarden.Bitwarden'
            IntelliJ = 'JetBrains.IntelliJIDEA'
            DotNet = 'Microsoft.DotNet.SDK.10'
            VCRedist = 'abbodi1406.vcredist'
            IntelDSA = 'Intel.IntelDriverAndSupportAssistant'
            CUDA = 'Nvidia.CUDA'
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
        CudaLegacyVersion = '12.9'
        CudaLegacyComponents = @(
            'nvcc', 'cudart', 'thrust', 'cublas', 'cublas_dev',
            'cufft', 'cufft_dev', 'curand', 'curand_dev',
            'cusolver', 'cusolver_dev', 'cusparse', 'cusparse_dev',
            'npp', 'npp_dev', 'nvjpeg', 'nvjpeg_dev',
            'nvrtc', 'nvrtc_dev', 'nvjitlink', 'nvtx'
        )
    }
    Desktop = @{
        NodeMinimum = '20.19.0'
        GStreamer = '1.28.6'
        GStreamerInstaller = 'https://gstreamer.freedesktop.org/data/pkg/windows/1.28.6/msvc/gstreamer-1.0-msvc-x86_64-1.28.6.exe'
        Winget = @{
            VSCode = 'Microsoft.VisualStudioCode'
            Git = 'Git.Git'
            Node = 'OpenJS.NodeJS.LTS'
            Rustup = 'Rustlang.Rustup'
            BuildTools = 'Microsoft.VisualStudio.2022.BuildTools'
            WebView2 = 'Microsoft.EdgeWebView2Runtime'
            FFmpeg = 'Gyan.FFmpeg'
            CMake = 'Kitware.CMake'
            LLVM = 'LLVM.LLVM'
            LlamaCpp = 'ggml.llamacpp'
            OhMyPosh = 'JanDeDobbeleer.OhMyPosh'
            Starship = 'Starship.Starship'
            WindowsTerminal = 'Microsoft.WindowsTerminal'
        }
    }
}
