<#
================================================================================
    ZeroExplore - Fast, Safe & Intelligent Windows 10 / 11 File Explorer
    Part of the ZeroHub Ecosystem | High-Performance Dark Obsidian Edition
    Copyright (C) 2026 Amir Ali <https://zeroiq.site/>
    Licensed under the GNU General Public License v3.0 (GPLv3).
================================================================================
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseApprovedVerbs", "")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]
param()


# Enforce Single-Threaded Apartment (STA) for high-performance WPF
if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne [System.Threading.ApartmentState]::STA) {
    $rawPath = if ($PSCommandPath) { $PSCommandPath } elseif ($MyInvocation.MyCommand.Path) { $MyInvocation.MyCommand.Path } elseif ($PSScriptRoot) { Join-Path $PSScriptRoot "ZeroExplore.ps1" } else { $MyInvocation.MyCommand.Definition }
    $resolvedPath = if ($rawPath -and (Test-Path -LiteralPath $rawPath)) { (Resolve-Path -LiteralPath $rawPath).Path } else { (Join-Path (Get-Location).Path "ZeroExplore.ps1") }
    $workingDir = if (Test-Path -LiteralPath $resolvedPath) { Split-Path -Parent $resolvedPath } else { (Get-Location).Path }
    Start-Process -FilePath "powershell.exe" -WorkingDirectory $workingDir -ArgumentList "-NoProfile -ExecutionPolicy Bypass -STA -File `"$resolvedPath`""
    return
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml, System.Drawing, System.Windows.Forms

# Embedded C# High-Performance File Engine
$cSharpEngine = @"
using System;
using System.IO;
using System.Text;
using System.Collections.Generic;
using System.Collections.Concurrent;
using System.ComponentModel;
using System.Threading;
using System.Threading.Tasks;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text.RegularExpressions;
using System.Windows;
using System.Windows.Documents;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Controls;

namespace ZeroExplore {
    public static class ShellNative {
        [DllImport("shell32.dll", CharSet = CharSet.Auto)]
        public static extern bool ShellExecuteEx(ref SHELLEXECUTEINFO lpExecInfo);

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
        public struct SHELLEXECUTEINFO {
            public int cbSize;
            public uint fMask;
            public IntPtr hwnd;
            [MarshalAs(UnmanagedType.LPTStr)]
            public string lpVerb;
            [MarshalAs(UnmanagedType.LPTStr)]
            public string lpFile;
            [MarshalAs(UnmanagedType.LPTStr)]
            public string lpParameters;
            [MarshalAs(UnmanagedType.LPTStr)]
            public string lpDirectory;
            public int nShow;
            public IntPtr hInstApp;
            public IntPtr hIDList;
            [MarshalAs(UnmanagedType.LPTStr)]
            public string lpClass;
            public IntPtr hkeyClass;
            public uint dwHotKey;
            public IntPtr hIcon;
            public IntPtr hProcess;
        }

        private const uint SEE_MASK_INVOKEIDLIST = 0x0000000C;

        public static bool ShowPropertiesDialog(string path) {
            if (string.IsNullOrEmpty(path)) return false;
            var sei = new SHELLEXECUTEINFO();
            sei.cbSize = Marshal.SizeOf(sei);
            sei.fMask = SEE_MASK_INVOKEIDLIST;
            sei.lpVerb = "properties";
            sei.lpFile = path;
            sei.nShow = 5;
            return ShellExecuteEx(ref sei);
        }

        public static bool ExecuteShellVerb(string path, string verb) {
            if (string.IsNullOrEmpty(path)) return false;
            var sei = new SHELLEXECUTEINFO();
            sei.cbSize = Marshal.SizeOf(sei);
            sei.fMask = SEE_MASK_INVOKEIDLIST;
            sei.lpVerb = verb;
            sei.lpFile = path;
            sei.nShow = 5;
            return ShellExecuteEx(ref sei);
        }

        public static void ShowOpenWithDialog(string path) {
            if (string.IsNullOrEmpty(path)) return;
            Process.Start("rundll32.exe", "shell32.dll,OpenAs_RunDLL " + path);
        }

        [DllImport("shell32.dll", SetLastError = true)]
        public static extern int SetCurrentProcessExplicitAppUserModelID([MarshalAs(UnmanagedType.LPWStr)] string AppID);

        [DllImport("user32.dll", CharSet = CharSet.Auto)]
        public static extern IntPtr SendMessage(IntPtr hWnd, int Msg, IntPtr wParam, IntPtr lParam);

        [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        public static extern IntPtr LoadImage(IntPtr hinst, string lpszName, uint uType, int cxDesired, int cyDesired, uint fuLoad);

        public const int WM_SETICON = 0x0080;
        public const int ICON_SMALL = 0;
        public const int ICON_BIG = 1;
        public const uint IMAGE_ICON = 1;
        public const uint LR_LOADFROMFILE = 0x00000010;

        public static void SetWindowIcons(IntPtr hWnd, string iconPath) {
            if (string.IsNullOrEmpty(iconPath) || !File.Exists(iconPath) || hWnd == IntPtr.Zero) return;
            try {
                IntPtr hIconBig = LoadImage(IntPtr.Zero, iconPath, IMAGE_ICON, 32, 32, LR_LOADFROMFILE);
                IntPtr hIconSmall = LoadImage(IntPtr.Zero, iconPath, IMAGE_ICON, 16, 16, LR_LOADFROMFILE);
                if (hIconBig != IntPtr.Zero) SendMessage(hWnd, WM_SETICON, (IntPtr)ICON_BIG, hIconBig);
                if (hIconSmall != IntPtr.Zero) SendMessage(hWnd, WM_SETICON, (IntPtr)ICON_SMALL, hIconSmall);
            } catch {}
        }

        [DllImport("shell32.dll")]
        public static extern int SHGetPropertyStoreForWindow(IntPtr hwnd, ref Guid riid, [MarshalAs(UnmanagedType.Interface)] out IPropertyStore propertyStore);

        public static void SetWindowAppId(IntPtr hWnd, string appId) {
            if (hWnd == IntPtr.Zero || string.IsNullOrEmpty(appId)) return;
            try {
                Guid guid = new Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99");
                IPropertyStore store;
                int hr = SHGetPropertyStoreForWindow(hWnd, ref guid, out store);
                if (hr == 0 && store != null) {
                    var pv = new PropVariant();
                    pv.vt = 31;
                    pv.pwszVal = Marshal.StringToCoTaskMemUni(appId);
                    try {
                        var key = AppUserModelIDKey;
                        store.SetValue(ref key, ref pv);
                        store.Commit();
                    } finally {
                        if (pv.pwszVal != IntPtr.Zero) Marshal.FreeCoTaskMem(pv.pwszVal);
                    }
                }
            } catch {}
        }

        [ComImport]
        [Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99")]
        [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
        public interface IPropertyStore {
            int GetCount(out uint cProps);
            int GetAt(uint iProp, out PropertyKey pkey);
            int GetValue(ref PropertyKey key, out PropVariant pv);
            int SetValue(ref PropertyKey key, ref PropVariant pv);
            int Commit();
        }

        [StructLayout(LayoutKind.Sequential, Pack = 4)]
        public struct PropertyKey {
            public Guid fmtid;
            public uint pid;
            public PropertyKey(Guid fmtid, uint pid) {
                this.fmtid = fmtid;
                this.pid = pid;
            }
        }

        [StructLayout(LayoutKind.Explicit)]
        public struct PropVariant {
            [FieldOffset(0)] public ushort vt;
            [FieldOffset(8)] public IntPtr pwszVal;
        }

        public static readonly PropertyKey AppUserModelIDKey = new PropertyKey(new Guid("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3"), 5);

        [ComImport]
        [Guid("00021401-0000-0000-C000-000000000046")]
        public class ShellLink {}

        [ComImport]
        [Guid("0000010b-0000-0000-C000-000000000046")]
        [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
        public interface IPersistFile {
            void GetClassID(out Guid pClassID);
            [PreserveSig] int IsDirty();
            void Load([MarshalAs(UnmanagedType.LPWStr)] string pszFileName, uint dwMode);
            void Save([MarshalAs(UnmanagedType.LPWStr)] string pszFileName, [MarshalAs(UnmanagedType.Bool)] bool fRemember);
            void SaveCompleted([MarshalAs(UnmanagedType.LPWStr)] string pszFileName);
            void GetCurFile([MarshalAs(UnmanagedType.LPWStr)] out string ppszFileName);
        }

        public static void SetShortcutAppId(string shortcutPath, string appId) {
            if (!File.Exists(shortcutPath)) return;
            try {
                var link = new ShellLink();
                var persistFile = (IPersistFile)link;
                persistFile.Load(shortcutPath, 2); // STGM_READWRITE

                var propStore = (IPropertyStore)link;
                var pv = new PropVariant();
                pv.vt = 31; // VT_LPWSTR
                pv.pwszVal = Marshal.StringToCoTaskMemUni(appId);
                try {
                    var key = AppUserModelIDKey;
                    propStore.SetValue(ref key, ref pv);
                    propStore.Commit();
                    persistFile.Save(shortcutPath, true);
                } finally {
                    if (pv.pwszVal != IntPtr.Zero) Marshal.FreeCoTaskMem(pv.pwszVal);
                }
            } catch {}
        }
    }

    public class FileItem : INotifyPropertyChanged {
        public string Name { get; set; }
        public string FullPath { get; set; }
        public string Extension { get; set; }
        public string ItemType { get; set; }
        public long SizeBytes { get; set; }

        private string _sizeFormatted;
        public string SizeFormatted {
            get { return _sizeFormatted; }
            set {
                if (_sizeFormatted != value) {
                    _sizeFormatted = value;
                    OnPropertyChanged("SizeFormatted");
                }
            }
        }
        public DateTime DateModified { get; set; }
        public string DateModifiedFormatted { get; set; }
        public string Attributes { get; set; }
        public bool IsDirectory { get; set; }
        public string IconSymbol { get; set; }
        public string IconColor { get; set; }
        public bool IsHidden { get; set; }
        public bool IsBanner { get; set; }

        public ImageSource IconImage { get; set; }
        public bool HasIconImage {
            get { return IconImage != null; }
        }

        private ImageSource _thumbnail;
        public ImageSource Thumbnail {
            get { return _thumbnail; }
            set {
                if (_thumbnail != value) {
                    _thumbnail = value;
                    OnPropertyChanged("Thumbnail");
                    OnPropertyChanged("HasThumbnail");
                }
            }
        }

        public bool HasThumbnail {
            get { return _thumbnail != null; }
        }

        public event PropertyChangedEventHandler PropertyChanged;
        protected void OnPropertyChanged(string propName) {
            var handler = PropertyChanged;
            if (handler != null) handler(this, new PropertyChangedEventArgs(propName));
        }
    }

    public static class FileExplorerEngine {
        private static SynchronizationContext _uiContext;
        public static Action OnFolderSizesCompleted;

        public static List<FileItem> SortItems(IEnumerable<FileItem> items, string sortBy, bool ascending) {
            if (items == null) return new List<FileItem>();
            var list = items as List<FileItem> ?? new List<FileItem>(items);
            
            var normalDirs = new List<FileItem>();
            var normalFiles = new List<FileItem>();
            var hiddenDirs = new List<FileItem>();
            var hiddenFiles = new List<FileItem>();

            foreach (var it in list) {
                if (it == null || it.IsBanner) continue;
                if (it.IsHidden) {
                    if (it.IsDirectory) hiddenDirs.Add(it);
                    else hiddenFiles.Add(it);
                } else {
                    if (it.IsDirectory) normalDirs.Add(it);
                    else normalFiles.Add(it);
                }
            }

            Action<List<FileItem>, List<FileItem>> sortGroup = (dirs, files) => {
                if (sortBy == "Date") {
                    dirs.Sort((a, b) => {
                        int cmp = ascending ? a.DateModified.CompareTo(b.DateModified) : b.DateModified.CompareTo(a.DateModified);
                        return cmp != 0 ? cmp : string.Compare(a.Name, b.Name, StringComparison.OrdinalIgnoreCase);
                    });
                    files.Sort((a, b) => {
                        int cmp = ascending ? a.DateModified.CompareTo(b.DateModified) : b.DateModified.CompareTo(a.DateModified);
                        return cmp != 0 ? cmp : string.Compare(a.Name, b.Name, StringComparison.OrdinalIgnoreCase);
                    });
                } else if (sortBy == "Size") {
                    dirs.Sort((a, b) => {
                        int cmp = ascending ? a.SizeBytes.CompareTo(b.SizeBytes) : b.SizeBytes.CompareTo(a.SizeBytes);
                        return cmp != 0 ? cmp : string.Compare(a.Name, b.Name, StringComparison.OrdinalIgnoreCase);
                    });
                    files.Sort((a, b) => {
                        int cmp = ascending ? a.SizeBytes.CompareTo(b.SizeBytes) : b.SizeBytes.CompareTo(a.SizeBytes);
                        return cmp != 0 ? cmp : string.Compare(a.Name, b.Name, StringComparison.OrdinalIgnoreCase);
                    });
                } else if (sortBy == "Type") {
                    dirs.Sort((a, b) => ascending ? string.Compare(a.Name, b.Name, StringComparison.OrdinalIgnoreCase)
                                                  : string.Compare(b.Name, a.Name, StringComparison.OrdinalIgnoreCase));
                    files.Sort((a, b) => {
                        int extCmp = string.Compare(a.Extension ?? "", b.Extension ?? "", StringComparison.OrdinalIgnoreCase);
                        return ascending ? (extCmp != 0 ? extCmp : string.Compare(a.Name, b.Name, StringComparison.OrdinalIgnoreCase))
                                         : (extCmp != 0 ? -extCmp : string.Compare(a.Name, b.Name, StringComparison.OrdinalIgnoreCase));
                    });
                } else { // "Name"
                    dirs.Sort((a, b) => ascending ? string.Compare(a.Name, b.Name, StringComparison.OrdinalIgnoreCase)
                                                  : string.Compare(b.Name, a.Name, StringComparison.OrdinalIgnoreCase));
                    files.Sort((a, b) => ascending ? string.Compare(a.Name, b.Name, StringComparison.OrdinalIgnoreCase)
                                                   : string.Compare(b.Name, a.Name, StringComparison.OrdinalIgnoreCase));
                }
            };

            sortGroup(normalDirs, normalFiles);
            sortGroup(hiddenDirs, hiddenFiles);

            int totalHidden = hiddenDirs.Count + hiddenFiles.Count;
            int totalNormal = normalDirs.Count + normalFiles.Count;
            int bannerCount = totalHidden > 0 ? 1 : 0;
            var res = new List<FileItem>(totalNormal + bannerCount + totalHidden);
            
            res.AddRange(normalDirs);
            res.AddRange(normalFiles);

            if (totalHidden > 0) {
                res.Add(new FileItem {
                    Name = "Hidden files and directories",
                    FullPath = "",
                    Extension = "",
                    ItemType = "Section Header",
                    SizeBytes = 0,
                    SizeFormatted = totalHidden == 1 ? "1 item" : totalHidden + " items",
                    DateModified = DateTime.MinValue,
                    DateModifiedFormatted = "",
                    Attributes = "",
                    IsDirectory = false,
                    IsHidden = false,
                    IsBanner = true,
                    IconSymbol = "\uE890",
                    IconColor = "#7E8299"
                });
                res.AddRange(hiddenDirs);
                res.AddRange(hiddenFiles);
            }

            return res;
        }
        private static readonly ConcurrentDictionary<string, ImageSource> _assetIcons = new ConcurrentDictionary<string, ImageSource>(StringComparer.OrdinalIgnoreCase);
        public static ImageSource FolderIcon { get; set; }

        public static void InitializeAssetIcons(string assetsDir) {
            if (string.IsNullOrEmpty(assetsDir) || !Directory.Exists(assetsDir)) return;
            try {
                _assetIcons.Clear();
                foreach (var file in Directory.GetFiles(assetsDir, "*.png")) {
                    string baseName = Path.GetFileNameWithoutExtension(file).ToLowerInvariant();
                    var img = LoadAssetBitmap(file);
                    if (img != null) {
                        _assetIcons[baseName] = img;
                    }
                }
                ImageSource fImg;
                if (_assetIcons.TryGetValue("folder", out fImg)) {
                    FolderIcon = fImg;
                }
            } catch {}
        }

        private static ImageSource LoadAssetBitmap(string path) {
            if (string.IsNullOrEmpty(path) || !File.Exists(path)) return null;
            try {
                using (var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite)) {
                    var bi = new BitmapImage();
                    bi.BeginInit();
                    bi.CacheOption = BitmapCacheOption.OnLoad;
                    bi.StreamSource = stream;
                    bi.EndInit();
                    bi.Freeze();
                    return bi;
                }
            } catch {
                return null;
            }
        }

        public static ImageSource GetAssetIconForExtension(string ext) {
            if (string.IsNullOrEmpty(ext)) return null;
            string cleanExt = ext.TrimStart('.').ToLowerInvariant();
            
            // 1. Direct match by exact filename (e.g. "json", "rar", "txt", "exe", "zip", "bat", "css", "cpp", "html", "pptx", "xlsx")
            ImageSource exact;
            if (_assetIcons.TryGetValue(cleanExt, out exact)) return exact;

            // 2. C# ("c-sharp.png")
            if (cleanExt == "cs" || cleanExt == "csx") {
                if (_assetIcons.TryGetValue("c-sharp", out exact)) return exact;
            }

            // 3. Python ("python.png")
            if (cleanExt == "py" || cleanExt == "pyw" || cleanExt == "ipynb" || cleanExt == "pyc" || cleanExt == "pyd") {
                if (_assetIcons.TryGetValue("python", out exact)) return exact;
            }

            // 4. JavaScript / TypeScript ("javascript.png")
            if (cleanExt == "js" || cleanExt == "mjs" || cleanExt == "cjs" || cleanExt == "jsx" ||
                cleanExt == "ts" || cleanExt == "tsx" || cleanExt == "vue" || cleanExt == "svelte") {
                if (_assetIcons.TryGetValue("javascript", out exact)) return exact;
            }

            // 5. C / C++ ("cpp.png")
            if (cleanExt == "c" || cleanExt == "h" || cleanExt == "hpp" || cleanExt == "cc" || cleanExt == "cxx" || cleanExt == "hxx") {
                if (_assetIcons.TryGetValue("cpp", out exact)) return exact;
            }

            // 6. Word documents ("docx-file.png")
            if (cleanExt == "docx" || cleanExt == "doc" || cleanExt == "rtf" || cleanExt == "odt" || cleanExt == "wps") {
                if (_assetIcons.TryGetValue("docx-file", out exact)) return exact;
            }

            // 7. Excel spreadsheets ("xlsx.png")
            if (cleanExt == "xlsx" || cleanExt == "xls" || cleanExt == "xlsm" || cleanExt == "xlsb" || cleanExt == "ods") {
                if (_assetIcons.TryGetValue("xlsx", out exact)) return exact;
            }

            // 8. PowerPoint presentations ("pptx.png")
            if (cleanExt == "pptx" || cleanExt == "ppt" || cleanExt == "pps" || cleanExt == "ppsx" || cleanExt == "odp") {
                if (_assetIcons.TryGetValue("pptx", out exact)) return exact;
            }

            // 9. Batch & Scripts ("bat.png")
            if (cleanExt == "bat" || cleanExt == "cmd" || cleanExt == "ps1" || cleanExt == "psm1" || cleanExt == "psd1" || cleanExt == "vbs" || cleanExt == "sh") {
                if (_assetIcons.TryGetValue("bat", out exact)) return exact;
            }

            // 10. Stylesheets ("css.png")
            if (cleanExt == "css" || cleanExt == "scss" || cleanExt == "sass" || cleanExt == "less") {
                if (_assetIcons.TryGetValue("css", out exact)) return exact;
            }

            // 11. HTML / Web ("html.png")
            if (cleanExt == "html" || cleanExt == "htm" || cleanExt == "xhtml" || cleanExt == "mhtml") {
                if (_assetIcons.TryGetValue("html", out exact)) return exact;
            }

            // 12. JSON ("json.png")
            if (cleanExt == "json" || cleanExt == "jsonc" || cleanExt == "json5") {
                if (_assetIcons.TryGetValue("json", out exact)) return exact;
            }

            // 13. System Libraries ("dll-file-format.png")
            if (cleanExt == "dll" || cleanExt == "sys" || cleanExt == "ocx" || cleanExt == "drv" || cleanExt == "bin") {
                if (_assetIcons.TryGetValue("dll-file-format", out exact)) return exact;
            }

            // 14. Images ("image.png")
            if (cleanExt == "png" || cleanExt == "jpg" || cleanExt == "jpeg" || cleanExt == "bmp" ||
                cleanExt == "gif" || cleanExt == "webp" || cleanExt == "ico" || cleanExt == "svg" ||
                cleanExt == "tif" || cleanExt == "tiff" || cleanExt == "jfif" || cleanExt == "psd" ||
                cleanExt == "raw" || cleanExt == "cr2" || cleanExt == "nef" || cleanExt == "heic" || cleanExt == "avif") {
                if (_assetIcons.TryGetValue("image", out exact)) return exact;
            }

            // 15. Videos ("video.png")
            if (cleanExt == "mp4" || cleanExt == "mkv" || cleanExt == "avi" || cleanExt == "mov" ||
                cleanExt == "wmv" || cleanExt == "webm" || cleanExt == "flv" || cleanExt == "m4v" ||
                cleanExt == "3gp" || cleanExt == "ts" || cleanExt == "vob" || cleanExt == "ogv") {
                if (_assetIcons.TryGetValue("video", out exact)) return exact;
            }

            // 16. Text & Configs ("txt.png")
            if (cleanExt == "txt" || cleanExt == "log" || cleanExt == "md" || cleanExt == "ini" || cleanExt == "cfg" ||
                cleanExt == "inf" || cleanExt == "conf" || cleanExt == "env" || cleanExt == "xml" ||
                cleanExt == "yaml" || cleanExt == "yml" || cleanExt == "toml" || cleanExt == "csv" || cleanExt == "tsv") {
                if (_assetIcons.TryGetValue("txt", out exact)) return exact;
            }

            // 17. Archives ("rar.png" or "zip.png")
            if (cleanExt == "rar") {
                if (_assetIcons.TryGetValue("rar", out exact)) return exact;
            }
            if (cleanExt == "zip" || cleanExt == "7z" || cleanExt == "tar" || cleanExt == "gz" || cleanExt == "bz2" ||
                cleanExt == "xz" || cleanExt == "tgz" || cleanExt == "iso" || cleanExt == "cab" ||
                cleanExt == "wim" || cleanExt == "arj") {
                if (_assetIcons.TryGetValue("zip", out exact)) return exact;
                if (_assetIcons.TryGetValue("rar", out exact)) return exact;
            }

            // 18. Executables ("exe.png")
            if (cleanExt == "exe" || cleanExt == "msi") {
                if (_assetIcons.TryGetValue("exe", out exact)) return exact;
            }

            return null;
        }

        private static readonly ConcurrentDictionary<string, ImageSource> _thumbnailCache = new ConcurrentDictionary<string, ImageSource>(StringComparer.OrdinalIgnoreCase);
        private static CancellationTokenSource _thumbnailCts;

        public static bool IsImageFile(string path) {
            if (string.IsNullOrEmpty(path)) return false;
            string ext = Path.GetExtension(path).ToLowerInvariant();
            return ext == ".png" || ext == ".jpg" || ext == ".jpeg" || ext == ".bmp" || ext == ".webp" || ext == ".gif" || ext == ".ico";
        }

        public static ImageSource LoadThumbnail(string path, int decodePixelWidth = 140) {
            if (string.IsNullOrEmpty(path) || !File.Exists(path)) return null;
            ImageSource cached;
            if (_thumbnailCache.TryGetValue(path, out cached)) return cached;

            try {
                using (var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite)) {
                    var bi = new BitmapImage();
                    bi.BeginInit();
                    bi.CacheOption = BitmapCacheOption.OnLoad;
                    bi.StreamSource = stream;
                    if (decodePixelWidth > 0) {
                        bi.DecodePixelWidth = decodePixelWidth;
                    }
                    bi.EndInit();
                    bi.Freeze();
                    _thumbnailCache[path] = bi;
                    return bi;
                }
            } catch {
                return null;
            }
        }

        public static void CancelThumbnailLoading() {
            if (_thumbnailCts != null) {
                try {
                    _thumbnailCts.Cancel();
                    _thumbnailCts.Dispose();
                } catch {}
                _thumbnailCts = null;
            }
        }

        public static void LoadThumbnailsAsync(IEnumerable<FileItem> items, int decodePixelWidth = 140) {
            CancelThumbnailLoading();
            _thumbnailCts = new CancellationTokenSource();
            var token = _thumbnailCts.Token;

            Task.Run(() => {
                foreach (var item in items) {
                    if (token.IsCancellationRequested) break;
                    if (item == null || item.IsDirectory || !IsImageFile(item.FullPath)) continue;
                    if (item.Thumbnail != null) continue;

                    ImageSource thumb = LoadThumbnail(item.FullPath, decodePixelWidth);
                    if (thumb != null && !token.IsCancellationRequested) {
                        if (_uiContext != null) {
                            _uiContext.Post(state => {
                                if (!token.IsCancellationRequested) {
                                    item.Thumbnail = thumb;
                                }
                            }, null);
                        } else {
                            item.Thumbnail = thumb;
                        }
                    }
                }
            }, token);
        }


        public static bool TryReadTextPreview(string filePath, out string textContent, out int lineCount, int maxChars = 2000000) {
            textContent = "";
            lineCount = 0;
            if (string.IsNullOrEmpty(filePath) || !File.Exists(filePath)) return false;
            try {
                var fi = new FileInfo(filePath);
                if (fi.Length > 10 * 1024 * 1024) return false; // Skip files > 10MB
                
                using (var fs = new FileStream(filePath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite)) {
                    int checkLen = (int)Math.Min(1024, fs.Length);
                    byte[] buffer = new byte[checkLen];
                    int bytesRead = fs.Read(buffer, 0, checkLen);
                    for (int i = 0; i < bytesRead; i++) {
                        if (buffer[i] == 0) return false; // Binary null byte indicates non-text
                    }
                    
                    fs.Position = 0;
                    using (var reader = new StreamReader(fs, Encoding.UTF8, true)) {
                        var sb = new StringBuilder();
                        string line;
                        int count = 0;
                        while ((line = reader.ReadLine()) != null) {
                            count++;
                            if (sb.Length < maxChars) {
                                if (sb.Length > 0) sb.AppendLine();
                                sb.Append(line);
                            }
                            if (count >= 500 && sb.Length >= maxChars) {
                                break;
                            }
                        }
                        lineCount = count;
                        if (sb.Length >= maxChars && count > 0) {
                            sb.AppendLine();
                            sb.AppendLine("[... Preview Truncated for Performance ...]");
                        }
                        textContent = sb.ToString();
                        return true;
                    }
                }
            } catch {
                return false;
            }
        }

        public static string GetLanguageName(string ext) {
            if (string.IsNullOrEmpty(ext)) return "TEXT / CODE";
            switch (ext.ToLowerInvariant()) {
                case ".ps1": case ".psm1": case ".psd1": return "POWERSHELL";
                case ".py": case ".pyw": return "PYTHON";
                case ".cs": case ".csx": return "C#";
                case ".cpp": case ".cxx": case ".cc": case ".h": case ".hpp": return "C / C++";
                case ".c": return "C";
                case ".js": case ".mjs": case ".cjs": return "JAVASCRIPT";
                case ".ts": return "TYPESCRIPT";
                case ".jsx": return "REACT JSX";
                case ".tsx": return "REACT TSX";
                case ".vue": return "VUE";
                case ".svelte": return "SVELTE";
                case ".json": case ".jsonc": case ".json5": return "JSON";
                case ".xml": case ".axaml": return "XML";
                case ".xaml": return "WPF XAML";
                case ".html": case ".htm": return "HTML";
                case ".css": return "CSS";
                case ".scss": case ".sass": return "SASS / SCSS";
                case ".less": return "LESS";
                case ".md": case ".markdown": return "MARKDOWN";
                case ".sql": return "SQL";
                case ".rs": return "RUST";
                case ".go": return "GO";
                case ".java": return "JAVA";
                case ".kt": case ".kts": return "KOTLIN";
                case ".swift": return "SWIFT";
                case ".sh": case ".bash": case ".zsh": return "SHELL SCRIPT";
                case ".bat": case ".cmd": return "BATCH";
                case ".yaml": case ".yml": return "YAML";
                case ".toml": return "TOML";
                case ".ini": case ".cfg": case ".conf": case ".config": case ".env": return "CONFIG";
                case ".php": return "PHP";
                case ".rb": return "RUBY";
                case ".lua": return "LUA";
                case ".r": return "R";
                case ".dart": return "DART";
                case ".svg": return "SVG CODE";
                case ".csv": return "CSV DATA";
                case ".tsv": return "TSV DATA";
                case ".log": return "LOG";
                case ".proto": return "PROTOBUF";
                case ".tex": return "LATEX";
                default: return "CODE / TEXT";
            }
        }

        public static void SetUIContext() {
            _uiContext = SynchronizationContext.Current ?? new SynchronizationContext();
        }

        public static List<FileItem> GetDirectoryItems(string dirPath) {
            var list = new List<FileItem>();
            if (string.IsNullOrEmpty(dirPath) || !Directory.Exists(dirPath)) {
                return list;
            }

            try {
                var di = new DirectoryInfo(dirPath);
                
                // Folders First
                try {
                    foreach (var dir in di.EnumerateDirectories()) {
                        if ((dir.Attributes & FileAttributes.Hidden) != 0 && (dir.Attributes & FileAttributes.System) != 0) {
                            continue;
                        }
                        bool isHidden = (dir.Attributes & FileAttributes.Hidden) != 0 || dir.Name.StartsWith(".");
                        list.Add(new FileItem {
                            Name = dir.Name,
                            FullPath = dir.FullName,
                            Extension = "<DIR>",
                            ItemType = "File Folder",
                            SizeBytes = 0,
                            SizeFormatted = "--",
                            DateModified = dir.LastWriteTime,
                            DateModifiedFormatted = dir.LastWriteTime.ToString("yyyy-MM-dd HH:mm"),
                            Attributes = dir.Attributes.ToString(),
                            IsDirectory = true,
                            IsHidden = isHidden,
                            IsBanner = false,
                            IconSymbol = "\uED25",
                            IconColor = isHidden ? "#C98720" : "#F59E0B",
                            IconImage = FolderIcon
                        });
                    }
                } catch {}

                // Files
                try {
                    foreach (var fi in di.EnumerateFiles()) {
                        if ((fi.Attributes & FileAttributes.Hidden) != 0 && (fi.Attributes & FileAttributes.System) != 0) {
                            continue;
                        }
                        bool isHidden = (fi.Attributes & FileAttributes.Hidden) != 0 || fi.Name.StartsWith(".");
                        string ext = fi.Extension.ToLowerInvariant();
                        string typeStr = GetReadableType(ext);
                        string iconStr = GetIconForExtension(ext);
                        string colorStr = GetColorForExtension(ext);
                        ImageSource iconImg = GetAssetIconForExtension(ext);

                        list.Add(new FileItem {
                            Name = fi.Name,
                            FullPath = fi.FullName,
                            Extension = ext,
                            ItemType = typeStr,
                            SizeBytes = fi.Length,
                            SizeFormatted = FormatSize(fi.Length),
                            DateModified = fi.LastWriteTime,
                            DateModifiedFormatted = fi.LastWriteTime.ToString("yyyy-MM-dd HH:mm"),
                            Attributes = fi.Attributes.ToString(),
                            IsDirectory = false,
                            IsHidden = isHidden,
                            IsBanner = false,
                            IconSymbol = iconStr,
                            IconColor = colorStr,
                            IconImage = iconImg
                        });
                    }
                } catch {}
            } catch {}

            return list;
        }

        public static string FormatSize(long bytes) {
            if (bytes <= 0) return "0 B";
            if (bytes < 1024) return bytes + " B";
            if (bytes < 1048576) return (bytes / 1024.0).ToString("0.##") + " KB";
            if (bytes < 1073741824) return (bytes / 1048576.0).ToString("0.##") + " MB";
            if (bytes < 1099511627776L) return (bytes / 1073741824.0).ToString("0.##") + " GB";
            return (bytes / 1099511627776.0).ToString("0.##") + " TB";
        }

        private static string GetReadableType(string ext) {
            switch (ext) {
                case ".exe": return "Executable";
                case ".dll": return "Application Extension";
                case ".sys": return "System Driver";
                case ".bat":
                case ".cmd": return "Batch Script";
                case ".ps1": return "PowerShell Script";
                case ".txt": return "Text Document";
                case ".log": return "Log File";
                case ".json": return "JSON File";
                case ".xml": return "XML File";
                case ".zip":
                case ".7z":
                case ".rar": return "Compressed Archive";
                case ".mp4":
                case ".mkv":
                case ".avi":
                case ".mov": return "Video File";
                case ".mp3":
                case ".wav":
                case ".flac": return "Audio File";
                case ".png":
                case ".jpg":
                case ".jpeg":
                case ".gif":
                case ".bmp":
                case ".webp": return "Image File";
                case ".pdf": return "PDF Document";
                case ".iso": return "Disc Image";
                default:
                    if (string.IsNullOrEmpty(ext)) return "File";
                    return ext.TrimStart('.').ToUpperInvariant() + " File";
            }
        }

        private static string GetIconForExtension(string ext) {
            switch (ext) {
                case ".exe":
                case ".msi": return "\uE7B5";
                case ".bat":
                case ".cmd":
                case ".ps1": return "\uE756";
                case ".zip":
                case ".7z":
                case ".rar":
                case ".tar":
                case ".gz": return "\uE8B9";
                case ".mp4":
                case ".mkv":
                case ".avi":
                case ".mov":
                case ".wmv": return "\uE714";
                case ".mp3":
                case ".wav":
                case ".flac":
                case ".aac":
                case ".m4a": return "\uE8D6";
                case ".png":
                case ".jpg":
                case ".jpeg":
                case ".gif":
                case ".bmp":
                case ".webp": return "\uEB9F";
                case ".txt":
                case ".log":
                case ".md": return "\uE8C4";
                case ".json":
                case ".xml":
                case ".yaml":
                case ".yml":
                case ".ini":
                case ".cfg": return "\uE943";
                case ".pdf": return "\uEA90";
                default: return "\uE7C3";
            }
        }

        private static string GetColorForExtension(string ext) {
            switch (ext) {
                case ".exe":
                case ".msi": return "#F87171";
                case ".bat":
                case ".cmd":
                case ".ps1": return "#4ADE80";
                case ".zip":
                case ".7z":
                case ".rar": return "#F59E0B";
                case ".mp4":
                case ".mkv":
                case ".avi":
                case ".mov": return "#A78BFA";
                case ".mp3":
                case ".wav":
                case ".flac": return "#EC4899";
                case ".png":
                case ".jpg":
                case ".jpeg":
                case ".gif":
                case ".webp": return "#38BDF8";
                case ".txt":
                case ".log":
                case ".md": return "#94A3B8";
                case ".json":
                case ".xml": return "#FBBF24";
                case ".pdf": return "#EF4444";
                default: return "#CBD5E1";
            }
        }

        public static long CalculateDirectorySizeFast(string path, CancellationToken token) {
            long total = 0;
            if (string.IsNullOrEmpty(path) || !Directory.Exists(path)) return 0;
            try {
                var stack = new Stack<string>();
                stack.Push(path);

                while (stack.Count > 0) {
                    if (token.IsCancellationRequested) break;
                    string current = stack.Pop();

                    try {
                        var di = new DirectoryInfo(current);
                        foreach (var fi in di.EnumerateFiles()) {
                            if (token.IsCancellationRequested) break;
                            total += fi.Length;
                        }

                        foreach (var sub in di.EnumerateDirectories()) {
                            if (token.IsCancellationRequested) break;
                            if ((sub.Attributes & FileAttributes.ReparsePoint) != 0) continue;
                            stack.Push(sub.FullName);
                        }
                    } catch {}
                }
            } catch {}
            return total;
        }

        public static void CalculateFolderSizesAsync(List<FileItem> items, CancellationToken token) {
            Task.Run(() => {
                try {
                    Parallel.ForEach(items, new ParallelOptions { MaxDegreeOfParallelism = 2, CancellationToken = token }, item => {
                        if (token.IsCancellationRequested) return;
                        if (!item.IsDirectory) return;

                        try {
                            long size = CalculateDirectorySizeFast(item.FullPath, token);
                            if (token.IsCancellationRequested) return;

                            string formatted = FormatSize(size);
                            if (_uiContext != null) {
                                _uiContext.Post(state => {
                                    item.SizeBytes = size;
                                    item.SizeFormatted = formatted;
                                }, null);
                            } else {
                                item.SizeBytes = size;
                                item.SizeFormatted = formatted;
                            }
                        } catch {}
                    });
                    if (_uiContext != null && OnFolderSizesCompleted != null) {
                        _uiContext.Post(state => {
                            try {
                                if (OnFolderSizesCompleted != null) OnFolderSizesCompleted();
                            } catch {}
                        }, null);
                    }
                } catch {}
            });
        }

        private static string GetUniqueFileName(string dir, string fileName) {
            string target = Path.Combine(dir, fileName);
            if (!File.Exists(target)) return target;
            string nameOnly = Path.GetFileNameWithoutExtension(fileName);
            string ext = Path.GetExtension(fileName);
            int i = 2;
            string candidate = Path.Combine(dir, nameOnly + " - Copy" + ext);
            if (!File.Exists(candidate)) return candidate;
            while (File.Exists(Path.Combine(dir, nameOnly + " - Copy (" + i + ")" + ext))) {
                i++;
            }
            return Path.Combine(dir, nameOnly + " - Copy (" + i + ")" + ext);
        }

        private static string GetUniqueDirectoryName(string dir, string dirName) {
            string target = Path.Combine(dir, dirName);
            if (!Directory.Exists(target)) return target;
            int i = 2;
            string candidate = Path.Combine(dir, dirName + " - Copy");
            if (!Directory.Exists(candidate)) return candidate;
            while (Directory.Exists(Path.Combine(dir, dirName + " - Copy (" + i + ")"))) {
                i++;
            }
            return Path.Combine(dir, dirName + " - Copy (" + i + ")");
        }

        public static double TransferProgress = 0.0;
        public static string TransferCurrentFile = "";
        public static bool TransferIsActive = false;
        public static bool TransferIsFinished = false;
        public static int TransferCount = 0;
        public static double TransferElapsedSeconds = 0.0;

        public static long GetTotalBytes(List<string> sourcePaths) {
            long total = 0;
            foreach (var src in sourcePaths) {
                if (string.IsNullOrEmpty(src)) continue;
                try {
                    if (File.Exists(src)) {
                        total += new FileInfo(src).Length;
                    } else if (Directory.Exists(src)) {
                        foreach (var f in Directory.GetFiles(src, "*", SearchOption.AllDirectories)) {
                            try { total += new FileInfo(f).Length; } catch {}
                        }
                    }
                } catch {}
            }
            return Math.Max(total, 1);
        }

        private static void CopyFileStream(string src, string dest, ref long bytesCopied, long totalBytes) {
            byte[] buffer = new byte[1024 * 1024]; // 1MB buffer
            using (FileStream inStream = new FileStream(src, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
            using (FileStream outStream = new FileStream(dest, FileMode.Create, FileAccess.Write, FileShare.None)) {
                int bytesRead;
                long lastReport = bytesCopied;
                while ((bytesRead = inStream.Read(buffer, 0, buffer.Length)) > 0) {
                    outStream.Write(buffer, 0, bytesRead);
                    bytesCopied += bytesRead;
                    if (bytesCopied - lastReport >= 512 * 1024 || bytesCopied >= totalBytes) {
                        lastReport = bytesCopied;
                        TransferProgress = Math.Min(100.0, Math.Round(((double)bytesCopied / totalBytes) * 100.0, 1));
                    }
                }
            }
        }

        private static void CopyDirectoryWithProgress(string sourceDir, string targetDir, ref long bytesCopied, long totalBytes) {
            Directory.CreateDirectory(targetDir);
            foreach (var file in Directory.GetFiles(sourceDir)) {
                string destFile = Path.Combine(targetDir, Path.GetFileName(file));
                CopyFileStream(file, destFile, ref bytesCopied, totalBytes);
            }
            foreach (var subDir in Directory.GetDirectories(sourceDir)) {
                string destSubDir = Path.Combine(targetDir, Path.GetFileName(subDir));
                CopyDirectoryWithProgress(subDir, destSubDir, ref bytesCopied, totalBytes);
            }
        }

        public static void StartPasteAsync(List<string> sourcePaths, string destinationDir, bool isCut) {
            TransferProgress = 0.0;
            TransferCurrentFile = sourcePaths.Count > 0 ? Path.GetFileName(sourcePaths[0]) : "";
            TransferIsActive = true;
            TransferIsFinished = false;
            TransferCount = 0;
            TransferElapsedSeconds = 0.0;

            Task.Run(() => {
                var sw = Stopwatch.StartNew();
                int count = 0;
                long totalBytes = GetTotalBytes(sourcePaths);
                long bytesCopied = 0;

                foreach (var src in sourcePaths) {
                    if (string.IsNullOrEmpty(src)) continue;
                    try {
                        if (File.Exists(src)) {
                            string fileName = Path.GetFileName(src);
                            TransferCurrentFile = fileName;
                            string target = Path.Combine(destinationDir, fileName);
                            if (!isCut) {
                                target = GetUniqueFileName(destinationDir, fileName);
                                CopyFileStream(src, target, ref bytesCopied, totalBytes);
                            } else {
                                if (File.Exists(target)) target = GetUniqueFileName(destinationDir, fileName);
                                if (Path.GetPathRoot(src).Equals(Path.GetPathRoot(destinationDir), StringComparison.OrdinalIgnoreCase)) {
                                    File.Move(src, target);
                                    bytesCopied += new FileInfo(target).Length;
                                    TransferProgress = Math.Min(100.0, Math.Round(((double)bytesCopied / totalBytes) * 100.0, 1));
                                } else {
                                    CopyFileStream(src, target, ref bytesCopied, totalBytes);
                                    File.Delete(src);
                                }
                            }
                            count++;
                        } else if (Directory.Exists(src)) {
                            string dirName = new DirectoryInfo(src).Name;
                            TransferCurrentFile = dirName;
                            string target = Path.Combine(destinationDir, dirName);
                            if (!isCut) {
                                target = GetUniqueDirectoryName(destinationDir, dirName);
                                CopyDirectoryWithProgress(src, target, ref bytesCopied, totalBytes);
                            } else {
                                if (Path.GetPathRoot(src).Equals(Path.GetPathRoot(destinationDir), StringComparison.OrdinalIgnoreCase)) {
                                    if (Directory.Exists(target)) target = GetUniqueDirectoryName(destinationDir, dirName);
                                    Directory.Move(src, target);
                                    TransferProgress = Math.Min(100.0, Math.Round(((double)count / sourcePaths.Count) * 100.0, 1));
                                } else {
                                    target = GetUniqueDirectoryName(destinationDir, dirName);
                                    CopyDirectoryWithProgress(src, target, ref bytesCopied, totalBytes);
                                    Directory.Delete(src, true);
                                }
                            }
                            count++;
                        }
                    } catch (Exception ex) {
                        Debug.WriteLine("Paste error: " + ex);
                    }
                }

                sw.Stop();
                TransferProgress = 100.0;
                TransferCurrentFile = "Complete";
                TransferCount = count;
                TransferElapsedSeconds = Math.Round(sw.Elapsed.TotalSeconds, 1);
                TransferIsActive = false;
                TransferIsFinished = true;
            });
        }
    }

    public static class SyntaxEngine {
        // Dark Obsidian / VS Code Palette
        public static readonly SolidColorBrush BrushDefault  = FreezeBrush("#D4D4D8");
        public static readonly SolidColorBrush BrushKeyword  = FreezeBrush("#C586C0"); // Magenta/Purple
        public static readonly SolidColorBrush BrushString   = FreezeBrush("#CE9178"); // Warm Peach/Orange
        public static readonly SolidColorBrush BrushComment  = FreezeBrush("#6A9955"); // Muted Green
        public static readonly SolidColorBrush BrushNumber   = FreezeBrush("#B5CEA8"); // Mint Green
        public static readonly SolidColorBrush BrushVariable = FreezeBrush("#9CDCFE"); // Sky Blue
        public static readonly SolidColorBrush BrushType     = FreezeBrush("#4EC9B0"); // Turquoise / Teal
        public static readonly SolidColorBrush BrushFunction = FreezeBrush("#DCDCAA"); // Warm Yellow
        public static readonly SolidColorBrush BrushTag      = FreezeBrush("#569CD6"); // Blue
        public static readonly SolidColorBrush BrushAttrName = FreezeBrush("#9CDCFE"); // Sky Blue

        private static SolidColorBrush FreezeBrush(string hex) {
            var b = new SolidColorBrush((Color)ColorConverter.ConvertFromString(hex));
            b.Freeze();
            return b;
        }

        private static readonly Regex RegexGeneral = new Regex(
            @"(?<comment>(#|//|--|REM\b|::).*$)|" +
            @"(?<str>""(\\.|[^""])*""|'(\\.|[^'])*'|\x60(\\.|[^\x60])*\x60)|" +
            @"(?<var>(\$|@|%)[a-zA-Z0-9_:]+%?)|" +
            @"(?<num>\b(0x[0-9a-fA-F]+|\d+(\.\d+)?)\b)|" +
            @"(?<kw>\b(function|def|fn|func|param|if|else|elif|elseif|then|fi|return|yield|foreach|for|while|do|loop|in|of|try|catch|finally|except|throw|raise|class|struct|enum|interface|trait|impl|import|from|as|export|default|async|await|switch|case|break|continue|goto|public|private|protected|internal|static|virtual|override|abstract|readonly|new|typeof|sizeof|using|namespace|package|true|false|null|nil|None|True|False|select|insert|update|delete|where|join|echo)\b)|" +
            @"(?<type>\b([A-Z][a-zA-Z0-9_]*(\.[A-Z][a-zA-Z0-9_]*)*|int|string|bool|void|double|float|long|byte|char|object|var|let|const|val)\b)|" +
            @"(?<func>\b[a-zA-Z_][a-zA-Z0-9_-]*(?=\s*\())",
            RegexOptions.Compiled | RegexOptions.IgnoreCase
        );

        private static readonly Regex RegexJson = new Regex(
            @"(?<key>""(\\.|[^""])*""\s*:)|" +
            @"(?<str>""(\\.|[^""])*"")|" +
            @"(?<num>\b-?\d+(\.\d+)?([eE][+-]?\d+)?\b)|" +
            @"(?<kw>\b(true|false|null)\b)",
            RegexOptions.Compiled | RegexOptions.IgnoreCase
        );

        private static readonly Regex RegexXml = new Regex(
            @"(?<comment><!--[\s\S]*?-->)|" +
            @"(?<tag></?[a-zA-Z0-9_:-]+)|" +
            @"(?<attr>[a-zA-Z0-9_:-]+(?=\s*=))|" +
            @"(?<str>""(\\""|[^""])*""|'([^']|'''')*')|" +
            @"(?<tagend>/?>)",
            RegexOptions.Compiled | RegexOptions.IgnoreCase
        );

        private static readonly Regex RegexConfig = new Regex(
            @"(?<comment>(#|;).*$)|" +
            @"(?<section>\[.*?\])|" +
            @"(?<key>^[ \t]*[a-zA-Z0-9_.-]+(?=\s*[:=]))|" +
            @"(?<str>""(\\""|[^""])*""|'([^']|'''')*')|" +
            @"(?<num>\b\d+(\.\d+)?\b)|" +
            @"(?<kw>\b(true|false|yes|no|on|off)\b)",
            RegexOptions.Compiled | RegexOptions.IgnoreCase
        );

        public static bool IsCodingLanguage(string lang) {
            if (string.IsNullOrEmpty(lang)) return false;
            string l = lang.ToUpperInvariant();
            if (l.Contains("TEXT") || l.Contains("LOG") || l.Contains("CSV") || l.Contains("PLAIN")) return false;
            return true;
        }

        public static FlowDocument BuildDocument(string text, string lang) {
            var doc = new FlowDocument();
            doc.PagePadding = new System.Windows.Thickness(8, 6, 8, 6);
            doc.FontFamily = new FontFamily("Cascadia Code, Consolas, Courier New");
            doc.FontSize = 11.5;
            doc.Foreground = BrushDefault;
            doc.PageWidth = 4000;

            if (string.IsNullOrEmpty(text)) {
                var emptyP = new Paragraph(new Run(""));
                emptyP.Margin = new System.Windows.Thickness(0);
                doc.Blocks.Add(emptyP);
                return doc;
            }

            string[] lines = text.Split(new[] { "\r\n", "\n" }, StringSplitOptions.None);
            int maxLines = Math.Min(lines.Length, 4000);

            lang = (lang ?? "").ToUpperInvariant();
            bool isCode = IsCodingLanguage(lang);

            if (!isCode) {
                for (int i = 0; i < maxLines; i++) {
                    var p = new Paragraph(new Run(lines[i]));
                    p.Margin = new System.Windows.Thickness(0);
                    p.LineHeight = 17;
                    doc.Blocks.Add(p);
                }
                return doc;
            }

            bool isJson = lang.Contains("JSON");
            bool isXml = lang.Contains("XML") || lang.Contains("HTML") || lang.Contains("XAML") || lang.Contains("SVG");
            bool isConfig = lang.Contains("CONFIG") || lang.Contains("YAML") || lang.Contains("TOML") || lang.Contains("INI");
            
            Regex activeRegex = isJson ? RegexJson : (isXml ? RegexXml : (isConfig ? RegexConfig : RegexGeneral));

            for (int i = 0; i < maxLines; i++) {
                var p = new Paragraph();
                p.Margin = new System.Windows.Thickness(0);
                p.LineHeight = 17;
                
                string line = lines[i];
                if (string.IsNullOrEmpty(line)) {
                    p.Inlines.Add(new Run(""));
                    doc.Blocks.Add(p);
                    continue;
                }

                int lastIdx = 0;
                foreach (Match m in activeRegex.Matches(line)) {
                    if (m.Index > lastIdx) {
                        p.Inlines.Add(new Run(line.Substring(lastIdx, m.Index - lastIdx)) { Foreground = BrushDefault });
                    }

                    SolidColorBrush b = BrushDefault;
                    if (isJson) {
                        if (m.Groups["key"].Success) {
                            string k = m.Value;
                            int colIdx = k.LastIndexOf(':');
                            if (colIdx >= 0) {
                                p.Inlines.Add(new Run(k.Substring(0, colIdx)) { Foreground = BrushVariable });
                                p.Inlines.Add(new Run(k.Substring(colIdx)) { Foreground = BrushDefault });
                                lastIdx = m.Index + m.Length;
                                continue;
                            }
                            b = BrushVariable;
                        }
                        else if (m.Groups["str"].Success || m.Groups["str2"].Success) b = BrushString;
                        else if (m.Groups["num"].Success) b = BrushNumber;
                        else if (m.Groups["kw"].Success)  b = BrushTag;
                    }
                    else if (isXml) {
                        if (m.Groups["comment"].Success)   b = BrushComment;
                        else if (m.Groups["tag"].Success)  b = BrushTag;
                        else if (m.Groups["attr"].Success) b = BrushAttrName;
                        else if (m.Groups["str"].Success)  b = BrushString;
                        else if (m.Groups["tagend"].Success) b = BrushTag;
                    }
                    else if (isConfig) {
                        if (m.Groups["comment"].Success)   b = BrushComment;
                        else if (m.Groups["section"].Success) b = BrushKeyword;
                        else if (m.Groups["key"].Success)     b = BrushVariable;
                        else if (m.Groups["str"].Success)     b = BrushString;
                        else if (m.Groups["num"].Success)     b = BrushNumber;
                        else if (m.Groups["kw"].Success)      b = BrushTag;
                    }
                    else {
                        if (m.Groups["comment"].Success)   b = BrushComment;
                        else if (m.Groups["str"].Success)  b = BrushString;
                        else if (m.Groups["var"].Success)  b = BrushVariable;
                        else if (m.Groups["num"].Success)  b = BrushNumber;
                        else if (m.Groups["kw"].Success)   b = BrushKeyword;
                        else if (m.Groups["func"].Success) b = BrushFunction;
                        else if (m.Groups["type"].Success) b = BrushType;
                    }

                    p.Inlines.Add(new Run(m.Value) { Foreground = b });
                    lastIdx = m.Index + m.Length;
                }

                if (lastIdx < line.Length) {
                    p.Inlines.Add(new Run(line.Substring(lastIdx)) { Foreground = BrushDefault });
                }

                doc.Blocks.Add(p);
            }

            return doc;
        }

        public static string ExtractText(FlowDocument doc) {
            if (doc == null) return string.Empty;
            var range = new TextRange(doc.ContentStart, doc.ContentEnd);
            string t = range.Text;
            if (t.EndsWith("\r\n")) {
                t = t.Substring(0, t.Length - 2);
            } else if (t.EndsWith("\n")) {
                t = t.Substring(0, t.Length - 1);
            }
            return t;
        }
    }
}
"@

Add-Type -TypeDefinition $cSharpEngine -ReferencedAssemblies "System.Core", "WindowsBase", "System.Xml", "PresentationFramework", "PresentationCore", "System.Xaml" -Language CSharp

# Set unique AppUserModelID so Windows Taskbar never treats this window as PowerShell!
try {
    [void][ZeroExplore.ShellNative]::SetCurrentProcessExplicitAppUserModelID("ZeroExplore.FileExplorer.App")
} catch {}

[ZeroExplore.FileExplorerEngine]::SetUIContext()
$Script:AppDir = if ($PSScriptRoot) { $PSScriptRoot } elseif ($PSCommandPath) { Split-Path -Parent $PSCommandPath } else { (Get-Location).Path }
$Script:AssetsDir = if (Test-Path (Join-Path $Script:AppDir "assets")) {
    Join-Path $Script:AppDir "assets"
} else {
    Join-Path (Get-Location).Path "assets"
}
[ZeroExplore.FileExplorerEngine]::InitializeAssetIcons($Script:AssetsDir)
[ZeroExplore.FileExplorerEngine]::OnFolderSizesCompleted = [System.Action]{
    if ($Script:CurrentSortField -eq "Size") {
        Apply-ExplorerFilter
    }
}

# Global State
$Script:CurrentAppVersion       = "1.0.2"
$Script:GitHubRepo              = "ZeroIQs/ZeroExplorer"
$Script:RunningScriptPath       = if ($PSCommandPath) { $PSCommandPath } elseif ($PSScriptRoot) { Join-Path $PSScriptRoot "ZeroExplore.ps1" } else { (Join-Path (Get-Location).Path "ZeroExplore.ps1") }
$Script:HasAvailableUpdate      = $false
$Script:LatestUpdateTag         = $null
$Script:IsManualUpdateCheck     = $false
$Script:UpdateResetTimer        = $null
$Script:DefaultDrive            = if ($env:SystemDrive -and (Test-Path "$($env:SystemDrive)\")) { "$($env:SystemDrive)\" } else { [System.IO.Directory]::GetLogicalDrives()[0] }
$Script:ExplorerCurrentPath     = $Script:DefaultDrive
$Script:CurrentViewMode         = "Details" # "Details", "MediumIcons", "LargeIcons"
$Script:CurrentSortField        = "Name"    # "Name", "Date", "Size", "Type"
$Script:CurrentSortAscending    = $true
$Script:ExplorerHistory         = New-Object System.Collections.Generic.List[string]
$Script:ExplorerHistoryIndex    = -1
$Script:ExplorerAllItems        = New-Object System.Collections.Generic.List[ZeroExplore.FileItem]
$Script:SavedPreviewPaneWidth   = 360
$Script:IsMediaPlaying          = $false
$Script:IsMediaMuted            = $false
$Script:IsUserDraggingSlider    = $false

# Clipboard state for natural Copy/Cut/Paste
$Script:ClipboardItems          = New-Object System.Collections.Generic.List[string]
$Script:ClipboardMode           = "Copy" # "Copy" or "Cut"
$Script:ArchiveExtensions       = [System.Collections.Generic.HashSet[string]]::new([string[]]@(".zip", ".rar", ".7z", ".tar", ".gz", ".tgz", ".bz2", ".tbz2", ".xz", ".txz", ".iso", ".cab", ".wim", ".arj", ".lzh"), [System.StringComparer]::OrdinalIgnoreCase)

# Safe browser launch helper
function Open-SafeBrowserUrl([string]$url) {
    try {
        [System.Diagnostics.Process]::Start((New-Object System.Diagnostics.ProcessStartInfo($url) -Property @{ UseShellExecute = $true })) | Out-Null
    } catch {
        try { Start-Process $url } catch {}
    }
}

# Load XAML
[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:shell="clr-namespace:System.Windows.Shell;assembly=PresentationFramework"
        Title="ZeroExplore - Fast &amp; Intelligent Windows 10 / 11 File Explorer"
        Height="820" Width="1300" MinHeight="580" MinWidth="940"
        WindowStartupLocation="CenterScreen" WindowState="Normal"
        Background="#09090B" FontFamily="Segoe UI, Inter, Arial, sans-serif" Foreground="#F5EDE0">
  
  <WindowChrome.WindowChrome>
    <WindowChrome CaptionHeight="52" GlassFrameThickness="0" CornerRadius="0" ResizeBorderThickness="6" UseAeroCaptionButtons="False" />
  </WindowChrome.WindowChrome>

  <Window.Resources>
    <!-- Style for Icon Grid Cards -->
    <Style x:Key="IconCardItemStyle" TargetType="{x:Type ListBoxItem}">
      <Setter Property="FocusVisualStyle" Value="{x:Null}" />
      <Setter Property="Background" Value="Transparent" />
      <Setter Property="BorderBrush" Value="Transparent" />
      <Setter Property="BorderThickness" Value="1" />
      <Setter Property="Padding" Value="0" />
      <Setter Property="Margin" Value="4" />
      <Setter Property="Cursor" Value="Hand" />
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="{x:Type ListBoxItem}">
            <Border Name="CardBorder" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="7" Padding="4,6">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" />
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="CardBorder" Property="Background" Value="#1A1B24" />
                <Setter TargetName="CardBorder" Property="BorderBrush" Value="#2D2F3E" />
              </Trigger>
              <Trigger Property="IsSelected" Value="True">
                <Setter TargetName="CardBorder" Property="Background" Value="#2A1A14" />
                <Setter TargetName="CardBorder" Property="BorderBrush" Value="#c15f3c" />
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
      <Style.Triggers>
        <!-- Hidden Files & Directories Banner Section Header in Icon Grid -->
        <DataTrigger Binding="{Binding IsBanner}" Value="True">
          <Setter Property="Focusable" Value="False" />
          <Setter Property="IsHitTestVisible" Value="False" />
          <Setter Property="Template">
            <Setter.Value>
              <ControlTemplate TargetType="{x:Type ListBoxItem}">
                <Border Background="#14141B" BorderBrush="#252532" BorderThickness="0,1,0,1" Padding="14,6" Margin="0,10,0,6" MinWidth="2500">
                  <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                    <TextBlock Text="&#xE890;" FontFamily="Segoe MDL2 Assets" FontSize="12.5" Foreground="#7E8299" Margin="0,0,8,0" VerticalAlignment="Center" />
                    <TextBlock Text="{Binding Name}" FontWeight="Bold" FontSize="11" Foreground="#C7C8D6" VerticalAlignment="Center" Margin="0,0,10,0" />
                    <Border Background="#1D1D28" BorderBrush="#2D2D3E" BorderThickness="1" CornerRadius="4" Padding="6,1" VerticalAlignment="Center">
                      <TextBlock Text="{Binding SizeFormatted}" FontSize="9.5" FontWeight="SemiBold" Foreground="#88899C" VerticalAlignment="Center" />
                    </Border>
                  </StackPanel>
                </Border>
              </ControlTemplate>
            </Setter.Value>
          </Setter>
        </DataTrigger>
        <!-- Dimmed Opacity for Hidden Items -->
        <DataTrigger Binding="{Binding IsHidden}" Value="True">
          <Setter Property="Opacity" Value="0.65" />
        </DataTrigger>
      </Style.Triggers>
    </Style>

    <!-- Medium Icons Template -->
    <DataTemplate x:Key="IconGridMediumTemplate">
      <Grid Width="116" Height="126">
        <Grid.RowDefinitions>
          <RowDefinition Height="74" />
          <RowDefinition Height="34" />
          <RowDefinition Height="16" />
        </Grid.RowDefinitions>

        <Border Grid.Row="0" Background="#14151C" BorderBrush="#20212C" BorderThickness="1" CornerRadius="5" Margin="4" ClipToBounds="True">
          <Grid>
            <!-- 1. Real Image Thumbnail -->
            <Image Source="{Binding Thumbnail}" Stretch="UniformToFill" HorizontalAlignment="Center" VerticalAlignment="Center">
              <Image.Style>
                <Style TargetType="Image">
                  <Setter Property="Visibility" Value="Collapsed" />
                  <Style.Triggers>
                    <DataTrigger Binding="{Binding HasThumbnail}" Value="True">
                      <Setter Property="Visibility" Value="Visible" />
                    </DataTrigger>
                  </Style.Triggers>
                </Style>
              </Image.Style>
            </Image>
            <!-- 2. Custom Extension Icon Image -->
            <Image Source="{Binding IconImage}" Width="44" Height="44" Stretch="Uniform" RenderOptions.BitmapScalingMode="HighQuality" HorizontalAlignment="Center" VerticalAlignment="Center">
              <Image.Style>
                <Style TargetType="Image">
                  <Setter Property="Visibility" Value="Collapsed" />
                  <Style.Triggers>
                    <MultiDataTrigger>
                      <MultiDataTrigger.Conditions>
                        <Condition Binding="{Binding HasThumbnail}" Value="False" />
                        <Condition Binding="{Binding HasIconImage}" Value="True" />
                      </MultiDataTrigger.Conditions>
                      <Setter Property="Visibility" Value="Visible" />
                    </MultiDataTrigger>
                  </Style.Triggers>
                </Style>
              </Image.Style>
            </Image>
            <!-- 3. Fallback MDL2 Glyph -->
            <TextBlock Text="{Binding IconSymbol}" FontFamily="Segoe MDL2 Assets" FontSize="34" Foreground="{Binding IconColor}" HorizontalAlignment="Center" VerticalAlignment="Center">
              <TextBlock.Style>
                <Style TargetType="TextBlock">
                  <Setter Property="Visibility" Value="Collapsed" />
                  <Style.Triggers>
                    <MultiDataTrigger>
                      <MultiDataTrigger.Conditions>
                        <Condition Binding="{Binding HasThumbnail}" Value="False" />
                        <Condition Binding="{Binding HasIconImage}" Value="False" />
                      </MultiDataTrigger.Conditions>
                      <Setter Property="Visibility" Value="Visible" />
                    </MultiDataTrigger>
                  </Style.Triggers>
                </Style>
              </TextBlock.Style>
            </TextBlock>
          </Grid>
        </Border>

        <TextBlock Grid.Row="1" Text="{Binding Name}" TextWrapping="Wrap" TextTrimming="CharacterEllipsis"
                   FontSize="11" FontWeight="SemiBold" Foreground="#F5EDE0"
                   HorizontalAlignment="Center" TextAlignment="Center" Margin="3,2,3,0" MaxHeight="32" />

        <TextBlock Grid.Row="2" Text="{Binding SizeFormatted}" FontSize="9.5" Foreground="#71717A"
                   HorizontalAlignment="Center" TextAlignment="Center" />
      </Grid>
    </DataTemplate>

    <!-- Large Icons Template -->
    <DataTemplate x:Key="IconGridLargeTemplate">
      <Grid Width="160" Height="174">
        <Grid.RowDefinitions>
          <RowDefinition Height="114" />
          <RowDefinition Height="38" />
          <RowDefinition Height="18" />
        </Grid.RowDefinitions>

        <Border Grid.Row="0" Background="#14151C" BorderBrush="#20212C" BorderThickness="1" CornerRadius="6" Margin="4" ClipToBounds="True">
          <Grid>
            <!-- 1. Real Image Thumbnail -->
            <Image Source="{Binding Thumbnail}" Stretch="UniformToFill" HorizontalAlignment="Center" VerticalAlignment="Center">
              <Image.Style>
                <Style TargetType="Image">
                  <Setter Property="Visibility" Value="Collapsed" />
                  <Style.Triggers>
                    <DataTrigger Binding="{Binding HasThumbnail}" Value="True">
                      <Setter Property="Visibility" Value="Visible" />
                    </DataTrigger>
                  </Style.Triggers>
                </Style>
              </Image.Style>
            </Image>
            <!-- 2. Custom Extension Icon Image -->
            <Image Source="{Binding IconImage}" Width="68" Height="68" Stretch="Uniform" RenderOptions.BitmapScalingMode="HighQuality" HorizontalAlignment="Center" VerticalAlignment="Center">
              <Image.Style>
                <Style TargetType="Image">
                  <Setter Property="Visibility" Value="Collapsed" />
                  <Style.Triggers>
                    <MultiDataTrigger>
                      <MultiDataTrigger.Conditions>
                        <Condition Binding="{Binding HasThumbnail}" Value="False" />
                        <Condition Binding="{Binding HasIconImage}" Value="True" />
                      </MultiDataTrigger.Conditions>
                      <Setter Property="Visibility" Value="Visible" />
                    </MultiDataTrigger>
                  </Style.Triggers>
                </Style>
              </Image.Style>
            </Image>
            <!-- 3. Fallback MDL2 Glyph -->
            <TextBlock Text="{Binding IconSymbol}" FontFamily="Segoe MDL2 Assets" FontSize="52" Foreground="{Binding IconColor}" HorizontalAlignment="Center" VerticalAlignment="Center">
              <TextBlock.Style>
                <Style TargetType="TextBlock">
                  <Setter Property="Visibility" Value="Collapsed" />
                  <Style.Triggers>
                    <MultiDataTrigger>
                      <MultiDataTrigger.Conditions>
                        <Condition Binding="{Binding HasThumbnail}" Value="False" />
                        <Condition Binding="{Binding HasIconImage}" Value="False" />
                      </MultiDataTrigger.Conditions>
                      <Setter Property="Visibility" Value="Visible" />
                    </MultiDataTrigger>
                  </Style.Triggers>
                </Style>
              </TextBlock.Style>
            </TextBlock>
          </Grid>
        </Border>

        <TextBlock Grid.Row="1" Text="{Binding Name}" TextWrapping="Wrap" TextTrimming="CharacterEllipsis"
                   FontSize="12" FontWeight="SemiBold" Foreground="#F5EDE0"
                   HorizontalAlignment="Center" TextAlignment="Center" Margin="4,3,4,0" MaxHeight="36" />

        <TextBlock Grid.Row="2" Text="{Binding SizeFormatted}" FontSize="10" Foreground="#71717A"
                   HorizontalAlignment="Center" TextAlignment="Center" />
      </Grid>
    </DataTemplate>

    <!-- ZeroHub Dark Obsidian ScrollBar Style (Slim 8px, No White Gutters, Rounded Charcoal Thumb, Terracotta Hover) -->
    <Style x:Key="ModernScrollThumb" TargetType="{x:Type Thumb}">
      <Setter Property="OverridesDefaultStyle" Value="true" />
      <Setter Property="IsTabStop" Value="false" />
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="{x:Type Thumb}">
            <Border Background="#2A2A34" CornerRadius="4" Margin="1,2,1,2" />
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="true">
                <Setter Property="Background" Value="#c15f3c" />
              </Trigger>
              <Trigger Property="IsDragging" Value="true">
                <Setter Property="Background" Value="#A04C2E" />
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="{x:Type ScrollBar}">
      <Setter Property="Background" Value="Transparent" />
      <Setter Property="Width" Value="8" />
      <Setter Property="MinWidth" Value="8" />
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="{x:Type ScrollBar}">
            <Grid Background="Transparent">
              <Track Name="PART_Track" IsDirectionReversed="true">
                <Track.Thumb>
                  <Thumb Style="{StaticResource ModernScrollThumb}" />
                </Track.Thumb>
              </Track>
            </Grid>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
      <Style.Triggers>
        <Trigger Property="Orientation" Value="Horizontal">
          <Setter Property="Width" Value="Auto" />
          <Setter Property="Height" Value="8" />
          <Setter Property="MinHeight" Value="8" />
          <Setter Property="Template">
            <Setter.Value>
              <ControlTemplate TargetType="{x:Type ScrollBar}">
                <Grid Background="Transparent">
                  <Track Name="PART_Track" IsDirectionReversed="false">
                    <Track.Thumb>
                      <Thumb Style="{StaticResource ModernScrollThumb}" />
                    </Track.Thumb>
                  </Track>
                </Grid>
              </ControlTemplate>
            </Setter.Value>
          </Setter>
        </Trigger>
      </Style.Triggers>
    </Style>
    <!-- Dark Obsidian Slider Style for Media Player Timeline & Volume -->
    <Style x:Key="DarkObsidianSliderThumb" TargetType="{x:Type Thumb}">
      <Setter Property="OverridesDefaultStyle" Value="True" />
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="{x:Type Thumb}">
            <Border Name="ThumbCircle" Width="12" Height="12" Background="#F5EDE0" BorderBrush="#c15f3c" BorderThickness="2" CornerRadius="6">
              <Border.Effect>
                <DropShadowEffect BlurRadius="4" ShadowDepth="1" Opacity="0.5" Color="#000000" />
              </Border.Effect>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="ThumbCircle" Property="Background" Value="#FFFFFF" />
                <Setter TargetName="ThumbCircle" Property="BorderBrush" Value="#E07A58" />
              </Trigger>
              <Trigger Property="IsDragging" Value="True">
                <Setter TargetName="ThumbCircle" Property="Background" Value="#c15f3c" />
                <Setter TargetName="ThumbCircle" Property="BorderBrush" Value="#FFFFFF" />
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="SliderTrackRepeatButtonStyle" TargetType="{x:Type RepeatButton}">
      <Setter Property="OverridesDefaultStyle" Value="True" />
      <Setter Property="IsTabStop" Value="False" />
      <Setter Property="Focusable" Value="False" />
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="{x:Type RepeatButton}">
            <Rectangle Fill="Transparent" />
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="DarkObsidianSliderStyle" TargetType="{x:Type Slider}">
      <Setter Property="FocusVisualStyle" Value="{x:Null}" />
      <Setter Property="IsMoveToPointEnabled" Value="True" />
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="{x:Type Slider}">
            <Grid VerticalAlignment="Center" Background="Transparent" Height="20">
              <Border Height="4" Background="#23232E" CornerRadius="2" VerticalAlignment="Center" />
              <Track Name="PART_Track">
                <Track.DecreaseRepeatButton>
                  <RepeatButton Command="{x:Static Slider.DecreaseLarge}" Style="{StaticResource SliderTrackRepeatButtonStyle}" />
                </Track.DecreaseRepeatButton>
                <Track.IncreaseRepeatButton>
                  <RepeatButton Command="{x:Static Slider.IncreaseLarge}" Style="{StaticResource SliderTrackRepeatButtonStyle}" />
                </Track.IncreaseRepeatButton>
                <Track.Thumb>
                  <Thumb Style="{StaticResource DarkObsidianSliderThumb}" />
                </Track.Thumb>
              </Track>
            </Grid>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Media Player Button Style -->
    <Style x:Key="MediaControlButtonStyle" TargetType="Button">
      <Setter Property="Background" Value="#111114" />
      <Setter Property="BorderBrush" Value="#23232A" />
      <Setter Property="BorderThickness" Value="1" />
      <Setter Property="Foreground" Value="#F5EDE0" />
      <Setter Property="FocusVisualStyle" Value="{x:Null}" />
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border Name="Bd" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="4">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" />
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Bd" Property="Background" Value="#23232A" />
                <Setter TargetName="Bd" Property="BorderBrush" Value="#32323E" />
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Setter TargetName="Bd" Property="Background" Value="#16161C" />
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <!-- Authentic ZeroHub Scalloped Plaque Primary Button (b1) -->
    <Style x:Key="PrimaryButton" TargetType="Button">
      <Setter Property="FocusVisualStyle" Value="{x:Null}" />
      <Setter Property="Background" Value="#c15f3c" />
      <Setter Property="Foreground" Value="#FFFFFF" />
      <Setter Property="FontFamily" Value="Segoe UI, Inter, Arial, sans-serif" />
      <Setter Property="FontWeight" Value="Bold" />
      <Setter Property="FontSize" Value="11" />
      <Setter Property="Height" Value="26" />
      <Setter Property="Padding" Value="10,0" />
      <Setter Property="Cursor" Value="Hand" />
      <Setter Property="BorderThickness" Value="0" />
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Grid Height="{TemplateBinding Height}" Background="Transparent" SnapsToDevicePixels="True">
              <Grid.ColumnDefinitions>
                <ColumnDefinition Width="10" />
                <ColumnDefinition Width="*" />
                <ColumnDefinition Width="10" />
              </Grid.ColumnDefinitions>
              <Path Grid.Column="0" Fill="{TemplateBinding Background}" Stretch="Fill" Data="M 10,0 A 10,10 0 0 1 0,10 L 0,16 A 10,10 0 0 1 10,26 Z" />
              <Border Grid.Column="1" Background="{TemplateBinding Background}" Padding="{TemplateBinding Padding}">
                <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" />
              </Border>
              <Path Grid.Column="2" Fill="{TemplateBinding Background}" Stretch="Fill" Data="M 0,0 A 10,10 0 0 0 10,10 L 10,16 A 10,10 0 0 0 0,26 Z" />
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter Property="Background" Value="#D96E49" />
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Setter Property="Background" Value="#9A4526" />
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Authentic ZeroHub Chamfered Hexagonal Banner Button (b2) -->
    <Style x:Key="b2" TargetType="Button">
      <Setter Property="FocusVisualStyle" Value="{x:Null}" />
      <Setter Property="Background" Value="#141418" />
      <Setter Property="Foreground" Value="#D4D4D8" />
      <Setter Property="FontFamily" Value="Segoe UI, Inter, Arial, sans-serif" />
      <Setter Property="FontWeight" Value="SemiBold" />
      <Setter Property="FontSize" Value="11" />
      <Setter Property="Height" Value="26" />
      <Setter Property="Padding" Value="6,0" />
      <Setter Property="Cursor" Value="Hand" />
      <Setter Property="BorderThickness" Value="0" />
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Grid Height="{TemplateBinding Height}" Background="Transparent" SnapsToDevicePixels="True">
              <Grid.ColumnDefinitions>
                <ColumnDefinition Width="10" />
                <ColumnDefinition Width="*" />
                <ColumnDefinition Width="10" />
              </Grid.ColumnDefinitions>
              <Path Grid.Column="0" Fill="{TemplateBinding Background}" Stretch="Fill" Data="M 10,0 L 0,13 L 10,26 Z" />
              <Border Grid.Column="1" Background="{TemplateBinding Background}" Padding="{TemplateBinding Padding}">
                <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" />
              </Border>
              <Path Grid.Column="2" Fill="{TemplateBinding Background}" Stretch="Fill" Data="M 0,0 L 10,13 L 0,26 Z" />
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter Property="Background" Value="#251812" />
                <Setter Property="Foreground" Value="#c15f3c" />
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Setter Property="Background" Value="#381D14" />
                <Setter Property="Foreground" Value="#FFFFFF" />
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Toolbar Command Button (Windows 11 Explorer / ZeroHub Style with Icon + Text + Badge) -->
    <Style x:Key="ToolbarCommandButton" TargetType="Button">
      <Setter Property="FocusVisualStyle" Value="{x:Null}" />
      <Setter Property="Background" Value="Transparent" />
      <Setter Property="Foreground" Value="#F5EDE0" />
      <Setter Property="BorderBrush" Value="Transparent" />
      <Setter Property="BorderThickness" Value="1" />
      <Setter Property="Height" Value="28" />
      <Setter Property="Padding" Value="7,2" />
      <Setter Property="Cursor" Value="Hand" />
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border Name="Bd" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="5" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" SnapsToDevicePixels="True" />
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Bd" Property="Background" Value="#1A1A20" />
                <Setter TargetName="Bd" Property="BorderBrush" Value="#2A2A34" />
                <Setter Property="Foreground" Value="#FFFFFF" />
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Setter TargetName="Bd" Property="Background" Value="#251812" />
                <Setter TargetName="Bd" Property="BorderBrush" Value="#c15f3c" />
                <Setter Property="Foreground" Value="#FFFFFF" />
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Sleek Quick Pill Button (Rounded Corner Drive/Shortcut Style) -->
    <Style x:Key="QuickPillButton" TargetType="Button">
      <Setter Property="FocusVisualStyle" Value="{x:Null}" />
      <Setter Property="Background" Value="#141418" />
      <Setter Property="Foreground" Value="#E2E8F0" />
      <Setter Property="BorderBrush" Value="#242634" />
      <Setter Property="BorderThickness" Value="1" />
      <Setter Property="FontFamily" Value="Segoe UI, Inter, Arial, sans-serif" />
      <Setter Property="FontSize" Value="10.5" />
      <Setter Property="FontWeight" Value="SemiBold" />
      <Setter Property="Height" Value="26" />
      <Setter Property="Padding" Value="9,0" />
      <Setter Property="Cursor" Value="Hand" />
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border Name="Bd" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="5" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" SnapsToDevicePixels="True" />
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Bd" Property="Background" Value="#221814" />
                <Setter TargetName="Bd" Property="BorderBrush" Value="#c15f3c" />
                <Setter Property="Foreground" Value="#FFFFFF" />
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Setter TargetName="Bd" Property="Background" Value="#321D15" />
                <Setter TargetName="Bd" Property="BorderBrush" Value="#c15f3c" />
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Toolbar Icon Button (Rounded Corner, No Diamonds) -->
    <Style x:Key="ToolbarIconButton" TargetType="Button">
      <Setter Property="FocusVisualStyle" Value="{x:Null}" />
      <Setter Property="Background" Value="#141418" />
      <Setter Property="Foreground" Value="#D4D4D8" />
      <Setter Property="BorderBrush" Value="#23232A" />
      <Setter Property="BorderThickness" Value="1" />
      <Setter Property="Cursor" Value="Hand" />
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border Name="Bd" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="6" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" SnapsToDevicePixels="True" />
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Bd" Property="Background" Value="#231A15" />
                <Setter TargetName="Bd" Property="BorderBrush" Value="#c15f3c" />
                <Setter Property="Foreground" Value="#FFFFFF" />
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Setter TargetName="Bd" Property="Background" Value="#321B13" />
                <Setter TargetName="Bd" Property="BorderBrush" Value="#c15f3c" />
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Dark Obsidian Context Menu Style (Pure Dark, No White Gutter) -->
    <Style x:Key="DarkObsidianContextMenu" TargetType="ContextMenu">
      <Setter Property="Background" Value="#141418" />
      <Setter Property="BorderBrush" Value="#2A2220" />
      <Setter Property="BorderThickness" Value="1" />
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ContextMenu">
            <Border Background="#141418" BorderBrush="#2A2220" BorderThickness="1" CornerRadius="8" Padding="4">
              <Border.Effect>
                <DropShadowEffect BlurRadius="22" ShadowDepth="6" Opacity="0.75" Color="#000000" />
              </Border.Effect>
              <StackPanel IsItemsHost="True" KeyboardNavigation.DirectionalNavigation="Cycle" />
            </Border>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Dark Obsidian Separator Style -->
    <Style x:Key="DarkObsidianSeparator" TargetType="Separator">
      <Setter Property="Height" Value="1" />
      <Setter Property="Margin" Value="6,3" />
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Separator">
            <Border Background="#262734" Height="1" />
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Dark Obsidian MenuItem Style -->
    <Style x:Key="DarkObsidianMenuItem" TargetType="MenuItem">
      <Setter Property="Foreground" Value="#F5EDE0" />
      <Setter Property="FontSize" Value="11.5" />
      <Setter Property="FontFamily" Value="Segoe UI, Inter, Arial, sans-serif" />
      <Setter Property="Cursor" Value="Hand" />
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="MenuItem">
            <Grid>
              <Border x:Name="BgBorder" Background="Transparent" CornerRadius="5" Padding="8,6" Margin="2,1" BorderThickness="1" BorderBrush="Transparent">
                <Grid>
                  <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="22" />
                    <ColumnDefinition Width="*" MinWidth="135" />
                    <ColumnDefinition Width="Auto" />
                    <ColumnDefinition Width="Auto" />
                  </Grid.ColumnDefinitions>

                  <!-- Icon Column (Seamless Dark Integration, No White Gutter!) -->
                  <ContentPresenter x:Name="IconHost" Grid.Column="0" ContentSource="Icon" VerticalAlignment="Center" HorizontalAlignment="Center" Margin="0,0,6,0" />

                  <!-- Item Title / Header -->
                  <ContentPresenter Grid.Column="1" ContentSource="Header" RecognizesAccessKey="True" VerticalAlignment="Center" Margin="6,0,16,0" />

                  <!-- Keyboard Shortcut Gesture Text -->
                  <TextBlock x:Name="GestureText" Grid.Column="2" Text="{TemplateBinding InputGestureText}" Foreground="#8A8580" FontSize="10.5" VerticalAlignment="Center" Margin="8,0,4,0" />

                  <!-- Submenu Expansion Arrow -->
                  <TextBlock x:Name="Arrow" Grid.Column="3" Text="&#xE76C;" FontFamily="Segoe MDL2 Assets" FontSize="9" Foreground="#8A8580" VerticalAlignment="Center" Margin="8,0,2,0" Visibility="Collapsed" />
                </Grid>
              </Border>

              <!-- Submenu Popup Container -->
              <Popup x:Name="PART_Popup" AllowsTransparency="True" Placement="Right" VerticalOffset="-4" HorizontalOffset="2"
                     IsOpen="{Binding IsSubmenuOpen, RelativeSource={RelativeSource TemplatedParent}}"
                     Focusable="False" PopupAnimation="Fade">
                <Border Background="#141418" BorderBrush="#2A2220" BorderThickness="1" CornerRadius="8" Padding="4">
                  <Border.Effect>
                    <DropShadowEffect BlurRadius="22" ShadowDepth="6" Opacity="0.75" Color="#000000" />
                  </Border.Effect>
                  <StackPanel IsItemsHost="True" KeyboardNavigation.DirectionalNavigation="Cycle" />
                </Border>
              </Popup>
            </Grid>
            
            <ControlTemplate.Triggers>
              <!-- Hover / Selection State: Obsidian Bronze Glow -->
              <Trigger Property="IsHighlighted" Value="True">
                <Setter TargetName="BgBorder" Property="Background" Value="#2E1E19" />
                <Setter TargetName="BgBorder" Property="BorderBrush" Value="#5C2D22" />
                <Setter Property="Foreground" Value="#FFFFFF" />
                <Setter TargetName="GestureText" Property="Foreground" Value="#E0D4CC" />
                <Setter TargetName="Arrow" Property="Foreground" Value="#c15f3c" />
              </Trigger>
              <Trigger Property="IsSubmenuOpen" Value="True">
                <Setter TargetName="BgBorder" Property="Background" Value="#2E1E19" />
                <Setter TargetName="BgBorder" Property="BorderBrush" Value="#5C2D22" />
                <Setter Property="Foreground" Value="#FFFFFF" />
                <Setter TargetName="GestureText" Property="Foreground" Value="#E0D4CC" />
                <Setter TargetName="Arrow" Property="Foreground" Value="#c15f3c" />
              </Trigger>
              <Trigger Property="HasItems" Value="True">
                <Setter TargetName="Arrow" Property="Visibility" Value="Visible" />
                <Setter TargetName="GestureText" Property="Visibility" Value="Collapsed" />
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter Property="Foreground" Value="#555866" />
                <Setter TargetName="GestureText" Property="Foreground" Value="#3F414D" />
                <Setter TargetName="IconHost" Property="Opacity" Value="0.38" />
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Default ContextMenu, MenuItem and Separator Styles for Entire Window -->
    <Style TargetType="ContextMenu" BasedOn="{StaticResource DarkObsidianContextMenu}" />
    <Style TargetType="MenuItem" BasedOn="{StaticResource DarkObsidianMenuItem}" />
    <Style TargetType="Separator" BasedOn="{StaticResource DarkObsidianSeparator}" />

    <!-- ZeroHub Authentic Sidebar Navigation Item Style -->
    <Style x:Key="SidebarNavButton" TargetType="Button">
      <Setter Property="Background" Value="Transparent" />
      <Setter Property="BorderThickness" Value="0" />
      <Setter Property="Padding" Value="10,7" />
      <Setter Property="HorizontalAlignment" Value="Stretch" />
      <Setter Property="HorizontalContentAlignment" Value="Stretch" />
      <Setter Property="Cursor" Value="Hand" />
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border Name="Bd" Background="{TemplateBinding Background}" CornerRadius="6" Padding="{TemplateBinding Padding}">
              <ContentPresenter VerticalAlignment="Center" HorizontalAlignment="Stretch" SnapsToDevicePixels="True" />
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Bd" Property="Background" Value="#1C1410" />
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Setter TargetName="Bd" Property="Background" Value="#2B1610" />
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>

  <!-- ROOT GRID -->
  <Grid Name="RootGrid">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto" /> <!-- Row 0: Window Caption & Header -->
      <RowDefinition Height="*" />    <!-- Row 1: Main Layout (Sidebar + Content) -->
      <RowDefinition Height="Auto" /> <!-- Row 2: Status Bar -->
    </Grid.RowDefinitions>

    <!-- Row 0: Window Caption Bar -->
    <Border Grid.Row="0" Background="#050507" BorderBrush="#181820" BorderThickness="0,0,0,1" Padding="12,8">
      <DockPanel LastChildFill="True">
        <!-- Window Controls & Quick Pin Actions -->
        <StackPanel DockPanel.Dock="Right" Orientation="Horizontal" VerticalAlignment="Center" WindowChrome.IsHitTestVisibleInChrome="True">
          <!-- Add to Desktop Button -->
          <Button Name="BtnAddToDesktop" Height="26" Background="#14141A" BorderBrush="#252530" BorderThickness="1" Cursor="Hand" Margin="0,0,12,0" ToolTip="Add shortcut to Desktop">
            <Button.Style>
              <Style TargetType="Button">
                <Setter Property="Template">
                  <Setter.Value>
                    <ControlTemplate TargetType="Button">
                      <Border Name="Bd" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="5" Padding="8,3">
                        <ContentPresenter VerticalAlignment="Center" HorizontalAlignment="Center" />
                      </Border>
                      <ControlTemplate.Triggers>
                        <Trigger Property="IsMouseOver" Value="True">
                          <Setter TargetName="Bd" Property="Background" Value="#222230" />
                          <Setter TargetName="Bd" Property="BorderBrush" Value="#38BDF8" />
                        </Trigger>
                        <Trigger Property="IsPressed" Value="True">
                          <Setter TargetName="Bd" Property="Background" Value="#181824" />
                        </Trigger>
                      </ControlTemplate.Triggers>
                    </ControlTemplate>
                  </Setter.Value>
                </Setter>
              </Style>
            </Button.Style>
            <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
              <TextBlock Text="&#xE7F4;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#38BDF8" Margin="0,0,5,0" VerticalAlignment="Center" />
              <TextBlock Text="Add to Desktop" FontSize="10.5" FontWeight="SemiBold" Foreground="#E4E4E7" VerticalAlignment="Center" />
            </StackPanel>
          </Button>

          <Button Name="BtnWindowMin" Width="32" Height="26" Background="Transparent" BorderThickness="0" Foreground="#94A3B8" Cursor="Hand" ToolTip="Minimize">
            <Button.Style>
              <Style TargetType="Button">
                <Setter Property="Template">
                  <Setter.Value>
                    <ControlTemplate TargetType="Button">
                      <Border Name="Bd" Background="{TemplateBinding Background}" CornerRadius="4">
                        <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" />
                      </Border>
                      <ControlTemplate.Triggers>
                        <Trigger Property="IsMouseOver" Value="True">
                          <Setter TargetName="Bd" Property="Background" Value="#202028" />
                          <Setter Property="Foreground" Value="#F5EDE0" />
                        </Trigger>
                        <Trigger Property="IsPressed" Value="True">
                          <Setter TargetName="Bd" Property="Background" Value="#16161D" />
                        </Trigger>
                      </ControlTemplate.Triggers>
                    </ControlTemplate>
                  </Setter.Value>
                </Setter>
              </Style>
            </Button.Style>
            <TextBlock Text="&#xE921;" FontFamily="Segoe MDL2 Assets" FontSize="10" />
          </Button>
          <Button Name="BtnWindowMax" Width="32" Height="26" Background="Transparent" BorderThickness="0" Foreground="#94A3B8" Cursor="Hand" Margin="2,0" ToolTip="Maximize / Restore">
            <Button.Style>
              <Style TargetType="Button">
                <Setter Property="Template">
                  <Setter.Value>
                    <ControlTemplate TargetType="Button">
                      <Border Name="Bd" Background="{TemplateBinding Background}" CornerRadius="4">
                        <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" />
                      </Border>
                      <ControlTemplate.Triggers>
                        <Trigger Property="IsMouseOver" Value="True">
                          <Setter TargetName="Bd" Property="Background" Value="#202028" />
                          <Setter Property="Foreground" Value="#F5EDE0" />
                        </Trigger>
                        <Trigger Property="IsPressed" Value="True">
                          <Setter TargetName="Bd" Property="Background" Value="#16161D" />
                        </Trigger>
                      </ControlTemplate.Triggers>
                    </ControlTemplate>
                  </Setter.Value>
                </Setter>
              </Style>
            </Button.Style>
            <TextBlock Name="TxtMaxIcon" Text="&#xE922;" FontFamily="Segoe MDL2 Assets" FontSize="10" />
          </Button>
          <Button Name="BtnWindowClose" Width="34" Height="26" Background="Transparent" BorderThickness="0" Foreground="#94A3B8" Cursor="Hand" ToolTip="Close">
            <Button.Style>
              <Style TargetType="Button">
                <Setter Property="Template">
                  <Setter.Value>
                    <ControlTemplate TargetType="Button">
                      <Border Name="CloseBd" Background="{TemplateBinding Background}" CornerRadius="4">
                        <TextBlock Text="&#xE8BB;" FontFamily="Segoe MDL2 Assets" FontSize="10" Foreground="{TemplateBinding Foreground}" VerticalAlignment="Center" HorizontalAlignment="Center" />
                      </Border>
                      <ControlTemplate.Triggers>
                        <Trigger Property="IsMouseOver" Value="True">
                          <Setter TargetName="CloseBd" Property="Background" Value="#E11D48" />
                          <Setter Property="Foreground" Value="#FFFFFF" />
                        </Trigger>
                        <Trigger Property="IsPressed" Value="True">
                          <Setter TargetName="CloseBd" Property="Background" Value="#BE123C" />
                          <Setter Property="Foreground" Value="#FFFFFF" />
                        </Trigger>
                      </ControlTemplate.Triggers>
                    </ControlTemplate>
                  </Setter.Value>
                </Setter>
              </Style>
            </Button.Style>
          </Button>
        </StackPanel>

        <!-- Brand Logo & Title -->
        <StackPanel Orientation="Horizontal" VerticalAlignment="Center" WindowChrome.IsHitTestVisibleInChrome="True">
          <Border Name="BtnHeaderLogo" Background="Transparent" BorderThickness="0" Margin="0,0,10,0" Cursor="Hand" ToolTip="Visit Official Website (zeroiq.site)">
            <Grid>
              <Image Name="ImgHeaderLogo" Width="30" Height="30" Stretch="Uniform" RenderOptions.BitmapScalingMode="HighQuality" />
              <TextBlock Name="TxtHeaderFallbackLogo" Text="&#xEC50;" FontFamily="Segoe MDL2 Assets" FontSize="16" Foreground="#c15f3c" HorizontalAlignment="Center" VerticalAlignment="Center" />
            </Grid>
          </Border>
          <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
            <TextBlock Text="Zero" FontSize="18" FontWeight="Bold" Foreground="#c15f3c" />
            <TextBlock Text="Explore" FontSize="18" FontWeight="Bold" Foreground="#FDFBF7" />
          </StackPanel>
        </StackPanel>
      </DockPanel>
    </Border>

    <!-- Row 1: Main Layout (Left Sidebar + Content Area) -->
    <Grid Grid.Row="1">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="270" MinWidth="230" MaxWidth="360" /> <!-- Col 0: Left Sidebar (ZeroHub Proportions) -->
        <ColumnDefinition Width="*" />                                    <!-- Col 1: Main Content -->
      </Grid.ColumnDefinitions>

      <!-- ========================================================================= -->
      <!-- LEFT SIDEBAR                                                              -->
      <!-- ========================================================================= -->
      <Border Grid.Column="0" Background="#070709" BorderBrush="#181820" BorderThickness="0,0,1.5,0">
        <Grid>
          <Grid.RowDefinitions>
            <RowDefinition Height="*" />    <!-- Scrollable Navigation Items -->
            <RowDefinition Height="Auto" /> <!-- Sidebar Footer (ZeroHub info & links) -->
          </Grid.RowDefinitions>

          <!-- Navigation ScrollViewer -->
          <ScrollViewer Grid.Row="0" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="8,10">
            <StackPanel>
              <!-- SECTION 1: DRIVES & PARTITIONS (ZeroHub Storage Metric Tiles) -->
              <DockPanel LastChildFill="False" Margin="4,4,4,6">
                <TextBlock Text="SYSTEM DRIVES &amp; PARTITIONS" FontSize="9.5" FontWeight="Bold" Foreground="#c15f3c" DockPanel.Dock="Left" VerticalAlignment="Center" FontFamily="Segoe UI, Inter, Arial, sans-serif" />
                <Border Background="#1C1410" BorderBrush="#3A2016" BorderThickness="1" CornerRadius="4" Padding="5,1.5" DockPanel.Dock="Right" VerticalAlignment="Center">
                  <TextBlock Name="TxtDriveCountBadge" Text="DRIVES" FontSize="8.5" FontWeight="Bold" Foreground="#c15f3c" />
                </Border>
              </DockPanel>
              
              <!-- Dynamic Drive Buttons Container (Populated with ZeroHub Style Metric Tiles) -->
              <StackPanel Name="PanelExplorerDriveButtons" Orientation="Vertical" Margin="0,0,0,12" />

              <!-- SECTION 2: QUICK ACCESS SHORTCUTS -->
              <TextBlock Text="QUICK ACCESS" FontSize="9.5" FontWeight="Bold" Foreground="#c15f3c" Margin="8,4,8,6" FontFamily="Segoe UI, Inter, Arial, sans-serif" />
              
              <!-- Desktop -->
              <Border Name="Border_Quick_Desktop" CornerRadius="6" Margin="0,1.5" Background="Transparent">
                <Button Name="BtnQuickDesktop" Style="{StaticResource SidebarNavButton}" ToolTip="User Desktop Folder">
                  <Grid VerticalAlignment="Center">
                    <Grid.ColumnDefinitions>
                      <ColumnDefinition Width="22" />
                      <ColumnDefinition Width="*" />
                    </Grid.ColumnDefinitions>
                    <TextBlock Name="Icon_Quick_Desktop" Grid.Column="0" Text="&#xE7F4;" FontFamily="Segoe MDL2 Assets" FontSize="12.5" Foreground="#F59E0B" HorizontalAlignment="Center" VerticalAlignment="Center" />
                    <TextBlock Name="Txt_Quick_Desktop" Grid.Column="1" Text="Desktop" FontSize="11.5" FontWeight="SemiBold" Foreground="#F5EDE0" Margin="6,0,0,0" VerticalAlignment="Center" />
                  </Grid>
                </Button>
              </Border>

              <!-- Downloads -->
              <Border Name="Border_Quick_Downloads" CornerRadius="6" Margin="0,1.5" Background="Transparent">
                <Button Name="BtnQuickDownloads" Style="{StaticResource SidebarNavButton}" ToolTip="User Downloads Folder">
                  <Grid VerticalAlignment="Center">
                    <Grid.ColumnDefinitions>
                      <ColumnDefinition Width="22" />
                      <ColumnDefinition Width="*" />
                    </Grid.ColumnDefinitions>
                    <TextBlock Name="Icon_Quick_Downloads" Grid.Column="0" Text="&#xE896;" FontFamily="Segoe MDL2 Assets" FontSize="12.5" Foreground="#38BDF8" HorizontalAlignment="Center" VerticalAlignment="Center" />
                    <TextBlock Name="Txt_Quick_Downloads" Grid.Column="1" Text="Downloads" FontSize="11.5" FontWeight="SemiBold" Foreground="#F5EDE0" Margin="6,0,0,0" VerticalAlignment="Center" />
                  </Grid>
                </Button>
              </Border>

              <!-- Documents -->
              <Border Name="Border_Quick_Documents" CornerRadius="6" Margin="0,1.5" Background="Transparent">
                <Button Name="BtnQuickDocuments" Style="{StaticResource SidebarNavButton}" ToolTip="User Documents Folder">
                  <Grid VerticalAlignment="Center">
                    <Grid.ColumnDefinitions>
                      <ColumnDefinition Width="22" />
                      <ColumnDefinition Width="*" />
                    </Grid.ColumnDefinitions>
                    <TextBlock Name="Icon_Quick_Documents" Grid.Column="0" Text="&#xE8A5;" FontFamily="Segoe MDL2 Assets" FontSize="12.5" Foreground="#4ADE80" HorizontalAlignment="Center" VerticalAlignment="Center" />
                    <TextBlock Name="Txt_Quick_Documents" Grid.Column="1" Text="Documents" FontSize="11.5" FontWeight="SemiBold" Foreground="#F5EDE0" Margin="6,0,0,0" VerticalAlignment="Center" />
                  </Grid>
                </Button>
              </Border>

              <!-- AppData -->
              <Border Name="Border_Quick_AppData" CornerRadius="6" Margin="0,1.5" Background="Transparent">
                <Button Name="BtnQuickAppData" Style="{StaticResource SidebarNavButton}" ToolTip="Application Data (%LOCALAPPDATA%)">
                  <Grid VerticalAlignment="Center">
                    <Grid.ColumnDefinitions>
                      <ColumnDefinition Width="22" />
                      <ColumnDefinition Width="*" />
                    </Grid.ColumnDefinitions>
                    <TextBlock Name="Icon_Quick_AppData" Grid.Column="0" Text="&#xE713;" FontFamily="Segoe MDL2 Assets" FontSize="12.5" Foreground="#A1A1AA" HorizontalAlignment="Center" VerticalAlignment="Center" />
                    <TextBlock Name="Txt_Quick_AppData" Grid.Column="1" Text="AppData" FontSize="11.5" FontWeight="SemiBold" Foreground="#F5EDE0" Margin="6,0,0,0" VerticalAlignment="Center" />
                  </Grid>
                </Button>
              </Border>

              <!-- Temp -->
              <Border Name="Border_Quick_Temp" CornerRadius="6" Margin="0,1.5" Background="Transparent">
                <Button Name="BtnQuickTemp" Style="{StaticResource SidebarNavButton}" ToolTip="System Temp Folder (%TEMP%)">
                  <Grid VerticalAlignment="Center">
                    <Grid.ColumnDefinitions>
                      <ColumnDefinition Width="22" />
                      <ColumnDefinition Width="*" />
                    </Grid.ColumnDefinitions>
                    <TextBlock Name="Icon_Quick_Temp" Grid.Column="0" Text="&#xE823;" FontFamily="Segoe MDL2 Assets" FontSize="12.5" Foreground="#FB923C" HorizontalAlignment="Center" VerticalAlignment="Center" />
                    <TextBlock Name="Txt_Quick_Temp" Grid.Column="1" Text="Temp" FontSize="11.5" FontWeight="SemiBold" Foreground="#F5EDE0" Margin="6,0,0,0" VerticalAlignment="Center" />
                  </Grid>
                </Button>
              </Border>

              <!-- Recycle Bin (Default Quick Access) -->
              <Border Name="Border_Quick_RecycleBin" CornerRadius="6" Margin="0,1.5" Background="Transparent">
                <Button Name="BtnQuickRecycleBin" Style="{StaticResource SidebarNavButton}" ToolTip="Windows Recycle Bin">
                  <Grid VerticalAlignment="Center">
                    <Grid.ColumnDefinitions>
                      <ColumnDefinition Width="22" />
                      <ColumnDefinition Width="*" />
                    </Grid.ColumnDefinitions>
                    <TextBlock Name="Icon_Quick_RecycleBin" Grid.Column="0" Text="&#xE74D;" FontFamily="Segoe MDL2 Assets" FontSize="12.5" Foreground="#F87171" HorizontalAlignment="Center" VerticalAlignment="Center" />
                    <TextBlock Name="Txt_Quick_RecycleBin" Grid.Column="1" Text="Recycle Bin" FontSize="11.5" FontWeight="SemiBold" Foreground="#F5EDE0" Margin="6,0,0,0" VerticalAlignment="Center" />
                  </Grid>
                </Button>
              </Border>

              <!-- Dynamic User-Pinned Quick Access Folders -->
              <StackPanel Name="PanelQuickAccessCustom" Orientation="Vertical" AllowDrop="True" />




              <!-- SECTION 4: ABOUT & INFORMATION -->
              <TextBlock Text="INFORMATION" FontSize="9.5" FontWeight="Bold" Foreground="#c15f3c" Margin="8,12,8,6" FontFamily="Segoe UI, Inter, Arial, sans-serif" />

              <!-- About & Info Nav Button -->
              <Border Name="Border_Nav_About" CornerRadius="6" Margin="0,1.5" Background="Transparent">
                <Button Name="Nav_About" Style="{StaticResource SidebarNavButton}" ToolTip="About ZeroExplore &amp; System Telemetry">
                  <Grid VerticalAlignment="Center">
                    <Grid.ColumnDefinitions>
                      <ColumnDefinition Width="22" />
                      <ColumnDefinition Width="*" />
                    </Grid.ColumnDefinitions>
                    <TextBlock Name="Icon_Nav_About" Grid.Column="0" Text="&#xE946;" FontFamily="Segoe MDL2 Assets" FontSize="13" Foreground="#c15f3c" HorizontalAlignment="Center" VerticalAlignment="Center" />
                    <TextBlock Name="Txt_Nav_About" Grid.Column="1" Text="About &amp; Info" FontSize="11.5" FontWeight="SemiBold" Foreground="#F5EDE0" Margin="6,0,0,0" VerticalAlignment="Center" />
                  </Grid>
                </Button>
              </Border>
            </StackPanel>
          </ScrollViewer>

          <!-- Sidebar Footer: ZeroHub Info, Website & Donate Links -->
          <Border Grid.Row="1" Background="#060608" BorderBrush="#181820" BorderThickness="0,1,0,0" Padding="8,8">
            <StackPanel>
              <!-- Sidebar Live GitHub Update Button (Always Visible like ZeroHub) -->
              <Border Name="BorderSidebarUpdate" Background="#111114" BorderBrush="#23232A" BorderThickness="1" CornerRadius="6" Margin="0,0,0,6">
                <Button Name="BtnSidebarUpdate" Background="Transparent" BorderThickness="0" Padding="8,6" Cursor="Hand" ToolTip="Check for the latest ZeroExplorer releases on GitHub">
                  <Button.Style>
                    <Style TargetType="Button">
                      <Setter Property="Template">
                        <Setter.Value>
                          <ControlTemplate TargetType="Button">
                            <Border Name="InnerBtnBorder" Background="{TemplateBinding Background}" CornerRadius="5" Padding="{TemplateBinding Padding}">
                              <ContentPresenter HorizontalAlignment="Stretch" VerticalAlignment="Center" />
                            </Border>
                            <ControlTemplate.Triggers>
                              <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="InnerBtnBorder" Property="Background" Value="#18181C" />
                              </Trigger>
                            </ControlTemplate.Triggers>
                          </ControlTemplate>
                        </Setter.Value>
                      </Setter>
                    </Style>
                  </Button.Style>
                  <Grid>
                    <Grid.ColumnDefinitions>
                      <ColumnDefinition Width="Auto" />
                      <ColumnDefinition Width="*" />
                      <ColumnDefinition Width="Auto" />
                    </Grid.ColumnDefinitions>
                    <TextBlock Name="IconSidebarUpdate" Grid.Column="0" Text="&#xE72C;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#c15f3c" VerticalAlignment="Center" Margin="0,0,6,0" />
                    <TextBlock Name="TxtSidebarUpdate" Grid.Column="1" Text="Check for Updates" FontWeight="SemiBold" FontSize="10.5" Foreground="#F5EDE0" VerticalAlignment="Center" />
                    <TextBlock Name="BadgeSidebarUpdateArrow" Grid.Column="2" Text="&#xE76C;" FontFamily="Segoe MDL2 Assets" FontSize="9" FontWeight="Bold" Foreground="#A1A1AA" VerticalAlignment="Center" Margin="4,0,0,0" />
                  </Grid>
                </Button>
              </Border>

              <!-- Links: Website & Donate -->
              <Grid>
                <Grid.ColumnDefinitions>
                  <ColumnDefinition Width="*" />
                  <ColumnDefinition Width="6" />
                  <ColumnDefinition Width="*" />
                </Grid.ColumnDefinitions>
                <Button Grid.Column="0" Name="BtnSidebarWebsite" Style="{StaticResource b2}" Background="#141418" Foreground="#D4D4D8" Height="26" Padding="2,0" Cursor="Hand" ToolTip="Official Website: https://zeroiq.site">
                  <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" VerticalAlignment="Center">
                    <TextBlock Text="&#xE774;" FontFamily="Segoe MDL2 Assets" FontSize="10" Foreground="#4ADE80" Margin="0,0,4,0" VerticalAlignment="Center" />
                    <TextBlock Text="Website" FontWeight="SemiBold" FontSize="10.5" Foreground="#D4D4D8" VerticalAlignment="Center" />
                  </StackPanel>
                </Button>
                <Button Grid.Column="2" Name="BtnSidebarDonate" Style="{StaticResource b2}" Background="#141418" Foreground="#D4D4D8" Height="26" Padding="2,0" Cursor="Hand" ToolTip="Support Development: https://zeroiq.site/donate">
                  <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" VerticalAlignment="Center">
                    <TextBlock Text="&#xEB51;" FontFamily="Segoe MDL2 Assets" FontSize="10" Foreground="#c15f3c" Margin="0,0,4,0" VerticalAlignment="Center" />
                    <TextBlock Text="Donate" FontWeight="SemiBold" FontSize="10.5" Foreground="#D4D4D8" VerticalAlignment="Center" />
                  </StackPanel>
                </Button>
              </Grid>
            </StackPanel>
          </Border>
        </Grid>
      </Border>

      <!-- ========================================================================= -->
      <!-- RIGHT CONTENT AREA (Column 1)                                             -->
      <!-- ========================================================================= -->
      <Grid Grid.Column="1" Background="#09090B">
        <!-- VIEW 1: FILE EXPLORER WORKSPACE -->
        <Grid Name="ViewExplorerFiles" Visibility="Visible" Margin="10,8,10,0">
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto" /> <!-- Row 0: Address Bar & Navigation -->
            <RowDefinition Height="Auto" /> <!-- Row 1: Top Action Command Bar -->
            <RowDefinition Height="*" />    <!-- Row 2: DataGrid / Tiled Panes + Live Preview -->
          </Grid.RowDefinitions>

          <!-- Top Navigation Bar & Address Bar -->
          <Border Grid.Row="0" Background="#111114" BorderBrush="#23232A" BorderThickness="1" CornerRadius="8" Padding="8,6" Margin="0,0,0,6">
            <Grid>
              <Grid.ColumnDefinitions>
                <ColumnDefinition Width="Auto" />
                <ColumnDefinition Width="*" />
                <ColumnDefinition Width="Auto" />
                <ColumnDefinition Width="Auto" />
              </Grid.ColumnDefinitions>

              <!-- Navigation Buttons (Back, Forward, Up, Refresh, Home) -->
              <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center" Margin="0,0,8,0">
                <Button Name="BtnExplorerBack" Style="{StaticResource ToolbarIconButton}" Width="30" Height="28" Margin="0,0,4,0" ToolTip="Go Back (Alt+Left)">
                  <TextBlock Text="&#xE72B;" FontFamily="Segoe MDL2 Assets" FontSize="11.5" Foreground="#F5EDE0" HorizontalAlignment="Center" VerticalAlignment="Center" />
                </Button>
                <Button Name="BtnExplorerForward" Style="{StaticResource ToolbarIconButton}" Width="30" Height="28" Margin="0,0,4,0" ToolTip="Go Forward (Alt+Right)">
                  <TextBlock Text="&#xE72A;" FontFamily="Segoe MDL2 Assets" FontSize="11.5" Foreground="#F5EDE0" HorizontalAlignment="Center" VerticalAlignment="Center" />
                </Button>
                <Button Name="BtnExplorerUp" Style="{StaticResource ToolbarIconButton}" Width="30" Height="28" Margin="0,0,4,0" ToolTip="Up to Parent Directory (Alt+Up)">
                  <TextBlock Text="&#xE74A;" FontFamily="Segoe MDL2 Assets" FontSize="11.5" Foreground="#F5EDE0" HorizontalAlignment="Center" VerticalAlignment="Center" />
                </Button>
                <Button Name="BtnExplorerRefresh" Style="{StaticResource ToolbarIconButton}" Width="30" Height="28" Margin="0,0,4,0" ToolTip="Refresh Directory (F5)">
                  <TextBlock Text="&#xE72C;" FontFamily="Segoe MDL2 Assets" FontSize="11.5" Foreground="#4ADE80" HorizontalAlignment="Center" VerticalAlignment="Center" />
                </Button>
                <Button Name="BtnExplorerHome" Style="{StaticResource ToolbarIconButton}" Width="30" Height="28" ToolTip="User Home Folder">
                  <TextBlock Text="&#xE80F;" FontFamily="Segoe MDL2 Assets" FontSize="11.5" Foreground="#F5EDE0" HorizontalAlignment="Center" VerticalAlignment="Center" />
                </Button>
              </StackPanel>

              <!-- Address Bar with Icon -->
              <Border Grid.Column="1" Background="#141418" BorderBrush="#23232A" BorderThickness="1" CornerRadius="6" Height="28" Margin="0,0,8,0" VerticalAlignment="Center">
                <Grid>
                  <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto" />
                    <ColumnDefinition Width="*" />
                  </Grid.ColumnDefinitions>
                  <TextBlock Grid.Column="0" Text="&#xEC50;" FontFamily="Segoe MDL2 Assets" FontSize="12" Foreground="#F59E0B" VerticalAlignment="Center" Margin="8,0,6,0" />
                  <TextBox Name="TxtExplorerPath" Grid.Column="1" Background="Transparent" BorderThickness="0" Foreground="#FFFFFF" Padding="2,3" FontSize="11" FontWeight="SemiBold" VerticalAlignment="Center" ToolTip="Type directory path and press Enter" />
                </Grid>
              </Border>

              <!-- Go Button -->
              <Button Name="BtnExplorerGo" Grid.Column="2" Style="{StaticResource QuickPillButton}" Background="#1A241F" BorderBrush="#2D4D36" Foreground="#4ADE80" Height="28" Padding="10,0" FontSize="11" FontWeight="Bold" Margin="0,0,8,0" Cursor="Hand" ToolTip="Navigate to entered path">
                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                  <TextBlock Text="Go" FontWeight="Bold" Margin="0,0,4,0" VerticalAlignment="Center" />
                  <TextBlock Text="&#xE751;" FontFamily="Segoe MDL2 Assets" FontSize="10" VerticalAlignment="Center" />
                </StackPanel>
              </Button>

              <!-- Quick Filter Box with Icon -->
              <Border Grid.Column="3" Background="#141418" BorderBrush="#23232A" BorderThickness="1" CornerRadius="6" Width="210" Height="28" VerticalAlignment="Center">
                <Grid>
                  <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto" />
                    <ColumnDefinition Width="*" />
                  </Grid.ColumnDefinitions>
                  <TextBlock Grid.Column="0" Text="&#xE721;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#71717A" VerticalAlignment="Center" Margin="8,0,6,0" />
                  <TextBox Name="TxtExplorerFilter" Grid.Column="1" Background="Transparent" BorderThickness="0" Foreground="#F5EDE0" Padding="2,3" FontSize="11" VerticalAlignment="Center" ToolTip="Filter files and folders in current directory..." />
                </Grid>
              </Border>
            </Grid>
          </Border>

          <!-- Top Action Command Bar (Windows 11 Explorer / ZeroHub Style) -->
          <Border Grid.Row="1" Background="#111114" BorderBrush="#23232A" BorderThickness="1" CornerRadius="8" Padding="6,3" Margin="0,0,0,6" Height="36">
            <DockPanel LastChildFill="True">
              <!-- Right Side: File Sorter & View Mode Switcher -->
              <StackPanel Orientation="Horizontal" DockPanel.Dock="Right" VerticalAlignment="Center">
                <!-- File Sorter -->
                <Button Name="BtnToggleSort" Style="{StaticResource ToolbarCommandButton}" ToolTip="Sort files and folders (Click to choose sorting options)">
                  <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                    <TextBlock Name="IconSortGlyph" Text="&#xE8CB;" FontFamily="Segoe MDL2 Assets" FontSize="12" Foreground="#38BDF8" VerticalAlignment="Center" Margin="0,0,6,0" />
                    <TextBlock Text="Sort:" FontSize="11" FontWeight="SemiBold" Foreground="#9C9CA8" VerticalAlignment="Center" Margin="0,0,4,0" />
                    <TextBlock Name="TxtSortModeLabel" Text="Name" FontSize="11" FontWeight="Bold" Foreground="#F5EDE0" VerticalAlignment="Center" />
                    <TextBlock Name="IconSortDirection" Text="&#xE70E;" FontFamily="Segoe MDL2 Assets" FontSize="9" Foreground="#38BDF8" VerticalAlignment="Center" Margin="4,1,0,0" />
                  </StackPanel>
                </Button>

                <!-- Separator -->
                <Rectangle Width="1" Height="16" Fill="#23232A" Margin="6,0" VerticalAlignment="Center" />

                <!-- View Mode Switcher (Details / Medium Icons / Large Icons) -->
                <Button Name="BtnToggleViewMode" Style="{StaticResource ToolbarCommandButton}" ToolTip="Switch View: Details / Medium Icons / Large Icons (Ctrl+Scroll or Click to cycle)">
                  <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                    <TextBlock Name="IconViewModeGlyph" Text="&#xE179;" FontFamily="Segoe MDL2 Assets" FontSize="12.5" Foreground="#FBBF24" VerticalAlignment="Center" Margin="0,0,6,0" />
                    <TextBlock Text="View:" FontSize="11" FontWeight="SemiBold" Foreground="#9C9CA8" VerticalAlignment="Center" Margin="0,0,4,0" />
                    <TextBlock Name="TxtViewModeLabel" Text="Details" FontSize="11" FontWeight="Bold" Foreground="#F5EDE0" VerticalAlignment="Center" />
                  </StackPanel>
                </Button>
              </StackPanel>

              <!-- Left Side: File Actions -->
              <StackPanel Orientation="Horizontal" DockPanel.Dock="Left" VerticalAlignment="Center">
                <!-- Copy -->
                <Button Name="BtnCopy" Style="{StaticResource ToolbarCommandButton}" ToolTip="Copy selected items (Ctrl+C)">
                  <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                    <TextBlock Text="&#xE8C8;" FontFamily="Segoe MDL2 Assets" FontSize="12.5" Foreground="#38BDF8" VerticalAlignment="Center" Margin="0,0,6,0" />
                    <TextBlock Text="Copy" FontSize="11" FontWeight="SemiBold" Foreground="#F5EDE0" VerticalAlignment="Center" />
                  </StackPanel>
                </Button>

                <!-- Cut -->
                <Button Name="BtnCut" Style="{StaticResource ToolbarCommandButton}" ToolTip="Cut selected items (Ctrl+X)" Margin="3,0,0,0">
                  <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                    <TextBlock Text="&#xE8C6;" FontFamily="Segoe MDL2 Assets" FontSize="12.5" Foreground="#F59E0B" VerticalAlignment="Center" Margin="0,0,6,0" />
                    <TextBlock Text="Cut" FontSize="11" FontWeight="SemiBold" Foreground="#F5EDE0" VerticalAlignment="Center" />
                  </StackPanel>
                </Button>

                <!-- Paste with Badge -->
                <Button Name="BtnPaste" Style="{StaticResource ToolbarCommandButton}" ToolTip="Paste items into current folder (Ctrl+V)" Margin="3,0,0,0">
                  <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                    <TextBlock Text="&#xE77F;" FontFamily="Segoe MDL2 Assets" FontSize="13" Foreground="#4ADE80" VerticalAlignment="Center" Margin="0,0,6,0" />
                    <TextBlock Text="Paste" FontSize="11" FontWeight="Bold" Foreground="#F5EDE0" VerticalAlignment="Center" />
                    <Border Name="BadgePasteStatus" Visibility="Collapsed" Background="#162E20" BorderBrush="#265C38" BorderThickness="1" CornerRadius="4" Padding="5,1" Margin="6,0,0,0" VerticalAlignment="Center">
                      <TextBlock Name="TxtPasteBadge" Text="Ready" FontSize="8.5" FontWeight="Bold" Foreground="#4ADE80" />
                    </Border>
                  </StackPanel>
                </Button>

                <!-- Separator -->
                <Rectangle Width="1" Height="16" Fill="#23232A" Margin="8,0" VerticalAlignment="Center" />

                <!-- New Folder -->
                <Button Name="BtnNewFolder" Style="{StaticResource ToolbarCommandButton}" ToolTip="Create new folder (Ctrl+Shift+N)">
                  <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                    <TextBlock Text="&#xE8F4;" FontFamily="Segoe MDL2 Assets" FontSize="12.5" Foreground="#F59E0B" VerticalAlignment="Center" Margin="0,0,6,0" />
                    <TextBlock Text="New Folder" FontSize="11" FontWeight="SemiBold" Foreground="#F5EDE0" VerticalAlignment="Center" />
                  </StackPanel>
                </Button>

                <!-- New File -->
                <Button Name="BtnNewFile" Style="{StaticResource ToolbarCommandButton}" ToolTip="Create new empty text file (Ctrl+N)" Margin="3,0,0,0">
                  <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                    <TextBlock Text="&#xE7C3;" FontFamily="Segoe MDL2 Assets" FontSize="12" Foreground="#38BDF8" VerticalAlignment="Center" Margin="0,0,6,0" />
                    <TextBlock Text="New File" FontSize="11" FontWeight="SemiBold" Foreground="#F5EDE0" VerticalAlignment="Center" />
                  </StackPanel>
                </Button>

                <!-- Separator -->
                <Rectangle Width="1" Height="16" Fill="#23232A" Margin="8,0" VerticalAlignment="Center" />

                <!-- Rename (F2) -->
                <Button Name="BtnToolbarRename" Style="{StaticResource ToolbarCommandButton}" ToolTip="Rename selected item (F2)">
                  <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                    <TextBlock Text="&#xE8AC;" FontFamily="Segoe MDL2 Assets" FontSize="12" Foreground="#A78BFA" VerticalAlignment="Center" Margin="0,0,6,0" />
                    <TextBlock Text="Rename" FontSize="11" FontWeight="SemiBold" Foreground="#F5EDE0" VerticalAlignment="Center" />
                  </StackPanel>
                </Button>

                <!-- Delete (Del) -->
                <Button Name="BtnToolbarDelete" Style="{StaticResource ToolbarCommandButton}" ToolTip="Delete selected items (Del)" Margin="3,0,0,0">
                  <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                    <TextBlock Text="&#xE74D;" FontFamily="Segoe MDL2 Assets" FontSize="12" Foreground="#F87171" VerticalAlignment="Center" Margin="0,0,6,0" />
                    <TextBlock Text="Delete" FontSize="11" FontWeight="SemiBold" Foreground="#F5EDE0" VerticalAlignment="Center" />
                  </StackPanel>
                </Button>

                <!-- Separator -->
                <Rectangle Width="1" Height="16" Fill="#23232A" Margin="8,0" VerticalAlignment="Center" />

                <!-- Live Preview Toggle -->
                <Button Name="BtnTogglePreviewPane" Style="{StaticResource ToolbarCommandButton}" ToolTip="Toggle Live Preview pane on/off">
                  <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                    <TextBlock Text="&#xE890;" FontFamily="Segoe MDL2 Assets" FontSize="12.5" Foreground="#38BDF8" VerticalAlignment="Center" Margin="0,0,6,0" />
                    <TextBlock Text="Live Preview" FontSize="11" FontWeight="SemiBold" Foreground="#F5EDE0" VerticalAlignment="Center" />
                    <Border Name="BadgePreviewStatus" Background="#162E20" BorderBrush="#265C38" BorderThickness="1" CornerRadius="4" Padding="5,1" Margin="6,0,0,0" VerticalAlignment="Center">
                      <TextBlock Name="TxtBadgePreviewStatus" Text="ON" FontSize="8.5" FontWeight="Bold" Foreground="#4ADE80" />
                    </Border>
                  </StackPanel>
                </Button>
              </StackPanel>
            </DockPanel>
          </Border>

          <!-- Split Layout with DataGrid (Left) and Live Preview Inspector (Right) -->
          <Grid Grid.Row="2">
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="*" MinWidth="150" />
              <ColumnDefinition Name="ColSplitterPreview" Width="Auto" />
              <ColumnDefinition Name="ColPreviewPane" Width="380" MinWidth="100" />
            </Grid.ColumnDefinitions>

            <!-- Main Content Container: Single View vs Hyprland Tiling Panes -->
            <Grid Grid.Column="0">
              <!-- Single Workspace View: ExplorerDataGrid & ExplorerIconGrid -->
              <Grid Name="PanelExplorerSingleView" Visibility="Visible">
              <!-- Main DataGrid (Details View) -->
              <DataGrid Name="ExplorerDataGrid" AutoGenerateColumns="False" CanUserAddRows="False" IsReadOnly="True"
                        ClipboardCopyMode="None"
                        Background="#111114" Foreground="#FFFFFF" BorderBrush="#23232A" BorderThickness="1"
                        GridLinesVisibility="All" HorizontalGridLinesBrush="#16171E" VerticalGridLinesBrush="#16171E"
                        HeadersVisibility="Column" SelectionMode="Extended" SelectionUnit="FullRow"
                        FontSize="11.5" Cursor="Arrow" RowHeight="32"
                        EnableRowVirtualization="True" EnableColumnVirtualization="True"
                        VirtualizingStackPanel.IsVirtualizing="True" VirtualizingStackPanel.VirtualizationMode="Recycling"
                        ScrollViewer.CanContentScroll="True" ScrollViewer.HorizontalScrollBarVisibility="Disabled" ScrollViewer.VerticalScrollBarVisibility="Auto">
              
              <!-- Context Menu for Native Copy/Cut/Paste UX -->
                            <!-- Context Menu: Native Windows File Explorer Capabilities (Dark Obsidian Edition - No White Gutter!) -->
              <DataGrid.ContextMenu>
                <ContextMenu Name="ExplorerContextMenu" Background="#141418" BorderBrush="#2A2220" BorderThickness="1">
                  <ContextMenu.Template>
                    <ControlTemplate TargetType="ContextMenu">
                      <Border Background="#141418" BorderBrush="#2A2220" BorderThickness="1" CornerRadius="8" Padding="4">
                        <Border.Effect>
                          <DropShadowEffect BlurRadius="22" ShadowDepth="6" Opacity="0.75" Color="#000000" />
                        </Border.Effect>
                        <StackPanel IsItemsHost="True" KeyboardNavigation.DirectionalNavigation="Cycle" />
                      </Border>
                    </ControlTemplate>
                  </ContextMenu.Template>

                  <ContextMenu.Resources>
                    <!-- Custom Separator -->
                    <Style TargetType="Separator">
                      <Setter Property="Height" Value="1" />
                      <Setter Property="Margin" Value="6,3" />
                      <Setter Property="Template">
                        <Setter.Value>
                          <ControlTemplate TargetType="Separator">
                            <Border Background="#262734" Height="1" />
                          </ControlTemplate>
                        </Setter.Value>
                      </Setter>
                    </Style>

                    <!-- Custom MenuItem Template: ZeroHub Dark Obsidian Bronze Edition -->
                    <Style TargetType="MenuItem">
                      <Setter Property="Foreground" Value="#F5EDE0" />
                      <Setter Property="FontSize" Value="11.5" />
                      <Setter Property="FontFamily" Value="Segoe UI" />
                      <Setter Property="Cursor" Value="Hand" />
                      <Setter Property="Template">
                        <Setter.Value>
                          <ControlTemplate TargetType="MenuItem">
                            <Grid>
                              <Border x:Name="BgBorder" Background="Transparent" CornerRadius="5" Padding="8,6" Margin="2,1" BorderThickness="1" BorderBrush="Transparent">
                                <Grid>
                                  <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="22" />
                                    <ColumnDefinition Width="*" MinWidth="135" />
                                    <ColumnDefinition Width="Auto" />
                                    <ColumnDefinition Width="Auto" />
                                  </Grid.ColumnDefinitions>

                                  <!-- Icon Column (Seamless Dark Integration, No White Gutter!) -->
                                  <ContentPresenter x:Name="IconHost" Grid.Column="0" ContentSource="Icon" VerticalAlignment="Center" HorizontalAlignment="Center" Margin="0,0,6,0" />

                                  <!-- Item Title / Header -->
                                  <ContentPresenter Grid.Column="1" ContentSource="Header" RecognizesAccessKey="True" VerticalAlignment="Center" Margin="6,0,16,0" />

                                  <!-- Keyboard Shortcut Gesture Text -->
                                  <TextBlock x:Name="GestureText" Grid.Column="2" Text="{TemplateBinding InputGestureText}" Foreground="#8A8580" FontSize="10.5" VerticalAlignment="Center" Margin="8,0,4,0" />

                                  <!-- Submenu Expansion Arrow -->
                                  <TextBlock x:Name="Arrow" Grid.Column="3" Text="&#xE76C;" FontFamily="Segoe MDL2 Assets" FontSize="9" Foreground="#8A8580" VerticalAlignment="Center" Margin="8,0,2,0" Visibility="Collapsed" />
                                </Grid>
                              </Border>

                              <!-- Submenu Popup Container: Pure Obsidian Dark Mode -->
                              <Popup x:Name="PART_Popup" AllowsTransparency="True" Placement="Right" VerticalOffset="-4" HorizontalOffset="2"
                                     IsOpen="{Binding IsSubmenuOpen, RelativeSource={RelativeSource TemplatedParent}}"
                                     Focusable="False" PopupAnimation="Fade">
                                <Border Background="#141418" BorderBrush="#2A2220" BorderThickness="1" CornerRadius="8" Padding="4">
                                  <Border.Effect>
                                    <DropShadowEffect BlurRadius="22" ShadowDepth="6" Opacity="0.75" Color="#000000" />
                                  </Border.Effect>
                                  <StackPanel IsItemsHost="True" KeyboardNavigation.DirectionalNavigation="Cycle" />
                                </Border>
                              </Popup>
                            </Grid>
                            
                            <ControlTemplate.Triggers>
                              <!-- Hover / Selection State: Obsidian Bronze Warm Terracotta Glow -->
                              <Trigger Property="IsHighlighted" Value="True">
                                <Setter TargetName="BgBorder" Property="Background" Value="#2E1E19" />
                                <Setter TargetName="BgBorder" Property="BorderBrush" Value="#5C2D22" />
                                <Setter Property="Foreground" Value="#FFFFFF" />
                                <Setter TargetName="GestureText" Property="Foreground" Value="#E0D4CC" />
                                <Setter TargetName="Arrow" Property="Foreground" Value="#c15f3c" />
                              </Trigger>
                              <Trigger Property="IsSubmenuOpen" Value="True">
                                <Setter TargetName="BgBorder" Property="Background" Value="#2E1E19" />
                                <Setter TargetName="BgBorder" Property="BorderBrush" Value="#5C2D22" />
                                <Setter Property="Foreground" Value="#FFFFFF" />
                                <Setter TargetName="GestureText" Property="Foreground" Value="#E0D4CC" />
                                <Setter TargetName="Arrow" Property="Foreground" Value="#c15f3c" />
                              </Trigger>
                              <!-- Has Submenu Items Trigger -->
                              <Trigger Property="HasItems" Value="True">
                                <Setter TargetName="Arrow" Property="Visibility" Value="Visible" />
                                <Setter TargetName="GestureText" Property="Visibility" Value="Collapsed" />
                              </Trigger>
                              <!-- Disabled State Trigger -->
                              <Trigger Property="IsEnabled" Value="False">
                                <Setter Property="Foreground" Value="#555866" />
                                <Setter TargetName="GestureText" Property="Foreground" Value="#3F414D" />
                                <Setter TargetName="IconHost" Property="Opacity" Value="0.38" />
                              </Trigger>
                            </ControlTemplate.Triggers>
                          </ControlTemplate>
                        </Setter.Value>
                      </Setter>
                    </Style>
                  </ContextMenu.Resources>

                  <MenuItem Name="CtxMenuOpen" Header="Open" InputGestureText="Enter">
                    <MenuItem.Icon>
                      <TextBlock Text="&#xED25;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#38BDF8" />
                    </MenuItem.Icon>
                  </MenuItem>
                  
                  <MenuItem Name="CtxMenuOpenAdmin" Header="Run as administrator">
                    <MenuItem.Icon>
                      <TextBlock Text="&#xE7EF;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#F59E0B" />
                    </MenuItem.Icon>
                  </MenuItem>

                  <!-- Authentic WinRAR Extraction Section (Separated) -->
                  <Separator Name="CtxSepArchiveTop" Visibility="Collapsed" />

                  <MenuItem Name="CtxMenuWinRAROpen" Header="Open with WinRAR" Visibility="Collapsed">
                    <MenuItem.Icon>
                      <Image Name="ImgWinRar1" Width="16" Height="16" RenderOptions.BitmapScalingMode="HighQuality" />
                    </MenuItem.Icon>
                  </MenuItem>

                  <MenuItem Name="CtxMenuExtractDialog" Header="Extract files..." Visibility="Collapsed">
                    <MenuItem.Icon>
                      <Image Name="ImgWinRar2" Width="16" Height="16" RenderOptions.BitmapScalingMode="HighQuality" />
                    </MenuItem.Icon>
                  </MenuItem>

                  <MenuItem Name="CtxMenuExtractHere" Header="Extract Here" Visibility="Collapsed">
                    <MenuItem.Icon>
                      <Image Name="ImgWinRar3" Width="16" Height="16" RenderOptions.BitmapScalingMode="HighQuality" />
                    </MenuItem.Icon>
                  </MenuItem>

                  <Separator Name="CtxSepArchiveBottom" Visibility="Collapsed" />
                  
                  <MenuItem Name="CtxMenuOpenWith" Header="Open with...">
                    <MenuItem.Icon>
                      <TextBlock Text="&#xE7AC;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#A78BFA" />
                    </MenuItem.Icon>
                  </MenuItem>
                  
                  <MenuItem Name="CtxMenuOpenTerminal" Header="Open in Terminal">
                    <MenuItem.Icon>
                      <TextBlock Text="&#xE756;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#34D399" />
                    </MenuItem.Icon>
                  </MenuItem>
                  
                  <MenuItem Name="CtxMenuOpenExplorer" Header="Open in Windows Explorer">
                    <MenuItem.Icon>
                      <TextBlock Text="&#xE8A7;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#F59E0B" />
                    </MenuItem.Icon>
                  </MenuItem>
                  
                  <MenuItem Name="CtxMenuPinQuick" Header="Pin to Quick Access">
                    <MenuItem.Icon>
                      <TextBlock Text="&#xE718;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#F472B6" />
                    </MenuItem.Icon>
                  </MenuItem>
                  
                  <Separator Name="CtxSep1" />
                  
                  <MenuItem Name="CtxMenuCut" Header="Cut" InputGestureText="Ctrl+X">
                    <MenuItem.Icon>
                      <TextBlock Text="&#xE8C6;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#F59E0B" />
                    </MenuItem.Icon>
                  </MenuItem>
                  
                  <MenuItem Name="CtxMenuCopy" Header="Copy" InputGestureText="Ctrl+C">
                    <MenuItem.Icon>
                      <TextBlock Text="&#xE8C8;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#38BDF8" />
                    </MenuItem.Icon>
                  </MenuItem>
                  
                  <MenuItem Name="CtxMenuCopyPath" Header="Copy as path" InputGestureText="Shift+Ctrl+C">
                    <MenuItem.Icon>
                      <TextBlock Text="&#xE8F7;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#CBD5E1" />
                    </MenuItem.Icon>
                  </MenuItem>
                  
                  <MenuItem Name="CtxMenuPaste" Header="Paste" InputGestureText="Ctrl+V">
                    <MenuItem.Icon>
                      <TextBlock Text="&#xE77F;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#4ADE80" />
                    </MenuItem.Icon>
                  </MenuItem>
                  
                  <Separator Name="CtxSep2" />
                  
                  <MenuItem Name="CtxMenuShortcut" Header="Create shortcut">
                    <MenuItem.Icon>
                      <TextBlock Text="&#xE71B;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#60A5FA" />
                    </MenuItem.Icon>
                  </MenuItem>
                  
                  <MenuItem Name="CtxMenuDelete" Header="Delete" InputGestureText="Del">
                    <MenuItem.Icon>
                      <TextBlock Text="&#xE74D;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#F87171" />
                    </MenuItem.Icon>
                  </MenuItem>
                  
                  <MenuItem Name="CtxMenuRename" Header="Rename" InputGestureText="F2">
                    <MenuItem.Icon>
                      <TextBlock Text="&#xE8AC;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#FBBF24" />
                    </MenuItem.Icon>
                  </MenuItem>
                  
                  <Separator Name="CtxSep3" />
                  
                  <MenuItem Name="CtxMenuNew" Header="New">
                    <MenuItem.Icon>
                      <TextBlock Text="&#xE710;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#4ADE80" />
                    </MenuItem.Icon>
                    <MenuItem Name="CtxMenuNewFolder" Header="Folder" InputGestureText="Ctrl+Shift+N">
                      <MenuItem.Icon>
                        <TextBlock Text="&#xE8F4;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#F59E0B" />
                      </MenuItem.Icon>
                    </MenuItem>
                    <Separator />
                    <MenuItem Name="CtxMenuNewTxt" Header="Text Document (.txt)">
                      <MenuItem.Icon>
                        <TextBlock Text="&#xE7C3;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#38BDF8" />
                      </MenuItem.Icon>
                    </MenuItem>
                    <MenuItem Name="CtxMenuNewPs1" Header="PowerShell Script (.ps1)">
                      <MenuItem.Icon>
                        <TextBlock Text="&#xE756;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#38BDF8" />
                      </MenuItem.Icon>
                    </MenuItem>
                    <MenuItem Name="CtxMenuNewBat" Header="Batch File (.bat)">
                      <MenuItem.Icon>
                        <TextBlock Text="&#xE7B8;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#F59E0B" />
                      </MenuItem.Icon>
                    </MenuItem>
                  </MenuItem>
                  
                  <MenuItem Name="CtxMenuRefresh" Header="Refresh" InputGestureText="F5">
                    <MenuItem.Icon>
                      <TextBlock Text="&#xE72C;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#38BDF8" />
                    </MenuItem.Icon>
                  </MenuItem>
                  
                  <Separator Name="CtxSep4" />
                  
                  <MenuItem Name="CtxMenuProperties" Header="Properties" InputGestureText="Alt+Enter">
                    <MenuItem.Icon>
                      <TextBlock Text="&#xE90F;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#c15f3c" />
                    </MenuItem.Icon>
                  </MenuItem>
                </ContextMenu>
              </DataGrid.ContextMenu>

                            <DataGrid.Resources>
                <!-- ZeroHub Clean Medieval Dark Column Header -->
                <Style TargetType="{x:Type DataGridColumnHeader}">
                  <Setter Property="Background" Value="#2A2018" />
                  <Setter Property="Foreground" Value="#c15f3c" />
                  <Setter Property="FontWeight" Value="Bold" />
                  <Setter Property="FontFamily" Value="Segoe UI, Inter, Arial, sans-serif" />
                  <Setter Property="FontSize" Value="11.5" />
                  <Setter Property="Padding" Value="10,7" />
                  <Setter Property="BorderThickness" Value="0,0,1,1.5" />
                  <Setter Property="BorderBrush" Value="#23232A" />
                  <Setter Property="Template">
                    <Setter.Value>
                      <ControlTemplate TargetType="{x:Type DataGridColumnHeader}">
                        <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" Padding="{TemplateBinding Padding}">
                          <ContentPresenter HorizontalAlignment="Left" VerticalAlignment="Center" SnapsToDevicePixels="True" />
                        </Border>
                      </ControlTemplate>
                    </Setter.Value>
                  </Setter>
                </Style>

                <!-- ZeroHub Clean Dark DataGrid Row Style (Authentic, Smooth, No Vibecoded Borders) -->
                <Style TargetType="{x:Type DataGridRow}">
                  <Setter Property="Background" Value="Transparent" />
                  <Setter Property="Foreground" Value="#F5EDE0" />
                  <Setter Property="FontFamily" Value="Segoe UI, Inter, Arial, sans-serif" />
                  <Setter Property="SnapsToDevicePixels" Value="True" />
                  <Setter Property="BorderThickness" Value="0" />
                  <Setter Property="BorderBrush" Value="Transparent" />
                  <Style.Triggers>
                    <Trigger Property="IsMouseOver" Value="True">
                      <Setter Property="Background" Value="#18181C" />
                    </Trigger>
                    <Trigger Property="IsSelected" Value="True">
                      <Setter Property="Background" Value="#1E242C" />
                      <Setter Property="Foreground" Value="#FFFFFF" />
                    </Trigger>
                    <!-- Hidden Files & Directories Banner Section Header -->
                    <DataTrigger Binding="{Binding IsBanner}" Value="True">
                      <Setter Property="Focusable" Value="False" />
                      <Setter Property="IsHitTestVisible" Value="False" />
                      <Setter Property="Template">
                        <Setter.Value>
                          <ControlTemplate TargetType="{x:Type DataGridRow}">
                            <Border Background="#14141B" BorderBrush="#252532" BorderThickness="0,1,0,1" Padding="12,5" Margin="0,8,0,4">
                              <DockPanel LastChildFill="True">
                                <StackPanel Orientation="Horizontal" DockPanel.Dock="Left" VerticalAlignment="Center">
                                  <TextBlock Text="&#xE890;" FontFamily="Segoe MDL2 Assets" FontSize="12.5" Foreground="#7E8299" Margin="0,0,8,0" VerticalAlignment="Center" />
                                  <TextBlock Text="{Binding Name}" FontWeight="Bold" FontSize="11" Foreground="#C7C8D6" VerticalAlignment="Center" />
                                </StackPanel>
                                <Border DockPanel.Dock="Right" Background="#1D1D28" BorderBrush="#2D2D3E" BorderThickness="1" CornerRadius="4" Padding="6,1" HorizontalAlignment="Right" VerticalAlignment="Center">
                                  <TextBlock Text="{Binding SizeFormatted}" FontSize="9.5" FontWeight="SemiBold" Foreground="#88899C" VerticalAlignment="Center" />
                                </Border>
                              </DockPanel>
                            </Border>
                          </ControlTemplate>
                        </Setter.Value>
                      </Setter>
                    </DataTrigger>
                    <!-- Dimmed Opacity for Hidden Items (Authentic Pro Explorer UX) -->
                    <DataTrigger Binding="{Binding IsHidden}" Value="True">
                      <Setter Property="Opacity" Value="0.65" />
                    </DataTrigger>
                  </Style.Triggers>
                </Style>

                <!-- ZeroHub Clean DataGrid Cell Style -->
                <Style TargetType="{x:Type DataGridCell}">
                  <Setter Property="BorderThickness" Value="0" />
                  <Setter Property="Padding" Value="6,4" />
                  <Setter Property="FocusVisualStyle" Value="{x:Null}" />
                  <Setter Property="Template">
                    <Setter.Value>
                      <ControlTemplate TargetType="{x:Type DataGridCell}">
                        <Border Background="{TemplateBinding Background}" BorderThickness="0" Padding="{TemplateBinding Padding}">
                          <ContentPresenter VerticalAlignment="Center" />
                        </Border>
                      </ControlTemplate>
                    </Setter.Value>
                  </Setter>
                  <Style.Triggers>
                    <Trigger Property="IsSelected" Value="True">
                      <Setter Property="Background" Value="#1E242C" />
                      <Setter Property="Foreground" Value="#FFFFFF" />
                    </Trigger>
                  </Style.Triggers>
                </Style>
              </DataGrid.Resources>

              <DataGrid.Columns>
                <!-- Name Column: Always visible, expands to fill space, with ellipsis -->
                <DataGridTemplateColumn Header="Name" Width="*" MinWidth="110" SortMemberPath="Name">
                  <DataGridTemplateColumn.CellTemplate>
                    <DataTemplate>
                      <StackPanel Orientation="Horizontal" VerticalAlignment="Center" Margin="10,0,8,0">
                        <Grid Width="16" Height="16" Margin="0,0,9,0" VerticalAlignment="Center">
                          <Image Source="{Binding IconImage}" Width="16" Height="16" Stretch="Uniform" RenderOptions.BitmapScalingMode="HighQuality" VerticalAlignment="Center" HorizontalAlignment="Center">
                            <Image.Style>
                              <Style TargetType="Image">
                                <Setter Property="Visibility" Value="Collapsed" />
                                <Style.Triggers>
                                  <DataTrigger Binding="{Binding HasIconImage}" Value="True">
                                    <Setter Property="Visibility" Value="Visible" />
                                  </DataTrigger>
                                </Style.Triggers>
                              </Style>
                            </Image.Style>
                          </Image>
                          <TextBlock Text="{Binding IconSymbol}" FontFamily="Segoe MDL2 Assets" FontSize="13.5" Foreground="{Binding IconColor}" VerticalAlignment="Center" HorizontalAlignment="Center">
                            <TextBlock.Style>
                              <Style TargetType="TextBlock">
                                <Setter Property="Visibility" Value="Collapsed" />
                                <Style.Triggers>
                                  <DataTrigger Binding="{Binding HasIconImage}" Value="False">
                                    <Setter Property="Visibility" Value="Visible" />
                                  </DataTrigger>
                                </Style.Triggers>
                              </Style>
                            </TextBlock.Style>
                          </TextBlock>
                        </Grid>
                        <TextBlock Text="{Binding Name}" FontWeight="SemiBold" FontSize="11.5" Foreground="#F5EDE0" VerticalAlignment="Center" TextTrimming="CharacterEllipsis" />
                      </StackPanel>
                    </DataTemplate>
                  </DataGridTemplateColumn.CellTemplate>
                </DataGridTemplateColumn>

                <!-- Size Column: Monospace right-aligned -->
                <DataGridTemplateColumn Header="Size" Width="105" SortMemberPath="SizeBytes">
                  <DataGridTemplateColumn.CellTemplate>
                    <DataTemplate>
                      <TextBlock Text="{Binding SizeFormatted}" FontFamily="Consolas, monospace" FontSize="11" Foreground="#38BDF8" HorizontalAlignment="Right" VerticalAlignment="Center" Margin="0,0,14,0" />
                    </DataTemplate>
                  </DataGridTemplateColumn.CellTemplate>
                </DataGridTemplateColumn>

                <!-- Type Column: Encapsulated badge -->
                <DataGridTemplateColumn Header="Type" Width="130" SortMemberPath="ItemType">
                  <DataGridTemplateColumn.CellTemplate>
                    <DataTemplate>
                      <Border Background="#161720" BorderBrush="#242634" BorderThickness="1" CornerRadius="4" Padding="6,2" HorizontalAlignment="Left" VerticalAlignment="Center" Margin="2,0,0,0">
                        <TextBlock Text="{Binding ItemType}" Foreground="#94A3B8" FontSize="10.5" VerticalAlignment="Center" TextTrimming="CharacterEllipsis" />
                      </Border>
                    </DataTemplate>
                  </DataGridTemplateColumn.CellTemplate>
                </DataGridTemplateColumn>

                <!-- Date Modified Column -->
                <DataGridTemplateColumn Header="Date Modified" Width="150" SortMemberPath="DateModified">
                  <DataGridTemplateColumn.CellTemplate>
                    <DataTemplate>
                      <TextBlock Text="{Binding DateModifiedFormatted}" FontFamily="Consolas, monospace" FontSize="11" Foreground="#A1A1AA" VerticalAlignment="Center" Margin="8,0,10,0" />
                    </DataTemplate>
                  </DataGridTemplateColumn.CellTemplate>
                </DataGridTemplateColumn>
              </DataGrid.Columns>
            </DataGrid>

              <!-- Main Icon Grid (Medium / Large Icons View) -->
              <ListBox Name="ExplorerIconGrid" Visibility="Collapsed"
                       Background="#111114" BorderBrush="#23232A" BorderThickness="1"
                       ItemContainerStyle="{StaticResource IconCardItemStyle}"
                       ItemTemplate="{StaticResource IconGridMediumTemplate}"
                       SelectionMode="Extended" Cursor="Arrow"
                       ScrollViewer.HorizontalScrollBarVisibility="Disabled"
                       ScrollViewer.VerticalScrollBarVisibility="Auto"
                       VirtualizingStackPanel.IsVirtualizing="True">
                <ListBox.ItemsPanel>
                  <ItemsPanelTemplate>
                    <WrapPanel Orientation="Horizontal" Margin="6" />
                  </ItemsPanelTemplate>
                </ListBox.ItemsPanel>
              </ListBox>
              </Grid>

              <!-- Dynamic Hyprland Tiling Workspace Host -->
              <Grid Name="PanelTilingHost" Visibility="Collapsed" Background="#09090B" />
            </Grid>

            <!-- Splitter between DataGrid and Preview Pane (Interactive Real-Time Live Push) -->
            <GridSplitter Grid.Column="1" Name="PreviewGridSplitter" Width="6" HorizontalAlignment="Center" VerticalAlignment="Stretch" Background="#181820" ShowsPreview="False" Cursor="SizeWE" ResizeDirection="Columns" />

            <!-- Right: Live Preview Pane -->
            <Border Grid.Column="2" Name="PreviewPaneContainer" Background="#111114" BorderBrush="#23232A" BorderThickness="1" CornerRadius="8" Margin="4,0,0,0">
              <Grid>
                <Grid.RowDefinitions>
                  <RowDefinition Height="Auto" /> <!-- Header -->
                  <RowDefinition Height="*" />    <!-- Content Area -->
                  <RowDefinition Height="Auto" /> <!-- Footer Metadata & Actions -->
                </Grid.RowDefinitions>

                <!-- Preview Header -->
                <Border Grid.Row="0" Background="#16161C" BorderBrush="#23232A" BorderThickness="0,0,0,1" CornerRadius="8,8,0,0" Padding="12,8">
                  <DockPanel LastChildFill="True">
                    <Button Name="BtnHidePreviewPane" DockPanel.Dock="Right" Style="{StaticResource ToolbarIconButton}" Width="24" Height="24" ToolTip="Hide Previewer">
                      <TextBlock Text="&#xE711;" FontFamily="Segoe MDL2 Assets" FontSize="9" Foreground="#A1A1AA" HorizontalAlignment="Center" VerticalAlignment="Center" />
                    </Button>
                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                      <TextBlock Text="&#xE890;" FontFamily="Segoe MDL2 Assets" FontSize="12.5" Foreground="#38BDF8" Margin="0,0,8,0" VerticalAlignment="Center" />
                      <TextBlock Text="Live Preview" FontWeight="Bold" FontSize="11.5" Foreground="#F5EDE0" VerticalAlignment="Center" />
                    </StackPanel>
                  </DockPanel>
                </Border>

                <!-- Preview Content Switcher -->
                <Grid Grid.Row="1" Margin="8">
                  <!-- Empty State -->
                  <StackPanel Name="PanelPreviewEmpty" VerticalAlignment="Center" HorizontalAlignment="Center">
                    <TextBlock Text="&#xE8B7;" FontFamily="Segoe MDL2 Assets" FontSize="36" Foreground="#2A2B36" HorizontalAlignment="Center" Margin="0,0,0,10" />
                    <TextBlock Text="No Item Selected" FontWeight="SemiBold" FontSize="12" Foreground="#71717A" HorizontalAlignment="Center" />
                    <TextBlock Text="Select a file to inspect metadata and content" FontSize="10" Foreground="#52525B" HorizontalAlignment="Center" Margin="0,4,0,0" />
                  </StackPanel>

                  <!-- Image Preview -->
                  <Border Name="PanelPreviewImage" Visibility="Collapsed" Background="#0C0D11" CornerRadius="6" Padding="6">
                    <Image Name="PreviewImgControl" Stretch="Uniform" RenderOptions.BitmapScalingMode="HighQuality" />
                  </Border>

                  <!-- Video & Audio Studio Media Player Preview -->
                  <Grid Name="PanelPreviewVideo" Visibility="Collapsed">
                    <Grid.RowDefinitions>
                      <RowDefinition Height="*" />
                      <RowDefinition Height="Auto" />
                    </Grid.RowDefinitions>

                    <!-- Viewport Area (Click to Play/Pause) -->
                    <Border Name="BorderVideoContainer" Grid.Row="0" Background="#08080C" BorderBrush="#1C1D26" BorderThickness="1" CornerRadius="6" ClipToBounds="True" Cursor="Hand">
                      <Grid>
                        <!-- 1. The Video MediaElement -->
                        <MediaElement Name="PreviewMediaElement" LoadedBehavior="Manual" UnloadedBehavior="Manual" ScrubbingEnabled="True" Stretch="Uniform" />

                        <!-- 2. Audio File Display Card -->
                        <Grid Name="PanelAudioDisplay" Visibility="Collapsed" Background="#0C0D14" VerticalAlignment="Stretch" HorizontalAlignment="Stretch">
                          <StackPanel VerticalAlignment="Center" HorizontalAlignment="Center">
                            <Border Width="68" Height="68" Background="#161722" BorderBrush="#252738" BorderThickness="1" CornerRadius="34" HorizontalAlignment="Center" Margin="0,0,0,12">
                              <Border.Effect>
                                <DropShadowEffect BlurRadius="18" ShadowDepth="4" Opacity="0.5" Color="#38BDF8" />
                              </Border.Effect>
                              <TextBlock Text="&#xEC4F;" FontFamily="Segoe MDL2 Assets" FontSize="30" Foreground="#38BDF8" HorizontalAlignment="Center" VerticalAlignment="Center" />
                            </Border>
                            <TextBlock Name="TxtAudioTitle" Text="Audio Track" FontSize="13" FontWeight="Bold" Foreground="#F5EDE0" HorizontalAlignment="Center" TextAlignment="Center" TextTrimming="CharacterEllipsis" MaxWidth="280" />
                            <TextBlock Name="TxtAudioSub" Text="Playing Audio" FontSize="11" Foreground="#94A3B8" HorizontalAlignment="Center" Margin="0,4,0,0" />
                          </StackPanel>
                        </Grid>

                        <!-- 3. Big Centered Floating Play/Pause Button Overlay (Shown when paused) -->
                        <Border Name="OverlayPlayButton" Width="56" Height="56" Background="#C0141418" BorderBrush="#c15f3c" BorderThickness="1.5" CornerRadius="28" HorizontalAlignment="Center" VerticalAlignment="Center" IsHitTestVisible="False" Visibility="Collapsed">
                          <Border.Effect>
                            <DropShadowEffect BlurRadius="16" ShadowDepth="3" Opacity="0.6" Color="#000000" />
                          </Border.Effect>
                          <TextBlock Name="TxtOverlayPlayGlyph" Text="&#xE768;" FontFamily="Segoe MDL2 Assets" FontSize="20" Foreground="#F5EDE0" HorizontalAlignment="Center" VerticalAlignment="Center" Margin="3,0,0,0" />
                        </Border>

                        <!-- 4. Media Failed Fallback Card (Codec Not Supported) -->
                        <Grid Name="PanelMediaFailed" Visibility="Collapsed" Background="#0F1017" VerticalAlignment="Stretch" HorizontalAlignment="Stretch">
                          <StackPanel VerticalAlignment="Center" HorizontalAlignment="Center" Margin="16">
                            <TextBlock Text="&#xE714;" FontFamily="Segoe MDL2 Assets" FontSize="36" Foreground="#F87171" HorizontalAlignment="Center" Margin="0,0,0,8" />
                            <TextBlock Text="Preview Codec Unavailable" FontSize="12.5" FontWeight="Bold" Foreground="#F5EDE0" HorizontalAlignment="Center" />
                            <TextBlock Text="Windows Media Foundation cannot decode this format directly." FontSize="10.5" Foreground="#71717A" HorizontalAlignment="Center" TextAlignment="Center" Margin="0,4,0,12" TextWrapping="Wrap" MaxWidth="260" />
                            <Button Name="BtnMediaFailedOpen" Style="{StaticResource ToolbarCommandButton}" Padding="10,5" HorizontalAlignment="Center">
                              <StackPanel Orientation="Horizontal">
                                <TextBlock Text="&#xE8A7;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#38BDF8" Margin="0,0,6,0" VerticalAlignment="Center" />
                                <TextBlock Text="Open in Default Player" FontSize="11" FontWeight="SemiBold" Foreground="#F5EDE0" VerticalAlignment="Center" />
                              </StackPanel>
                            </Button>
                          </StackPanel>
                        </Grid>
                      </Grid>
                    </Border>

                    <!-- Player Controls Toolbar -->
                    <Border Grid.Row="1" Background="#14141A" BorderBrush="#23232A" BorderThickness="1" CornerRadius="6" Padding="10,8" Margin="0,6,0,0">
                      <StackPanel>
                        <!-- Timeline Slider & Time Label -->
                        <Grid Margin="0,0,0,6">
                          <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*" />
                            <ColumnDefinition Width="Auto" />
                          </Grid.ColumnDefinitions>
                          <Slider Name="SliderMediaTimeline" Grid.Column="0" Minimum="0" Maximum="100" Value="0" IsMoveToPointEnabled="True" VerticalAlignment="Center" Height="20" Cursor="Hand" Style="{StaticResource DarkObsidianSliderStyle}" />
                          <TextBlock Name="TxtMediaTimeLabel" Grid.Column="1" Text="00:00 / 00:00" FontFamily="Consolas, Cascadia Code" FontSize="10" Foreground="#A1A1AA" Margin="10,0,0,0" VerticalAlignment="Center" />
                        </Grid>

                        <!-- Buttons & Volume Bar -->
                        <Grid>
                          <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto" />
                            <ColumnDefinition Width="Auto" />
                            <ColumnDefinition Width="Auto" />
                            <ColumnDefinition Width="Auto" />
                            <ColumnDefinition Width="*" />
                            <ColumnDefinition Width="Auto" />
                            <ColumnDefinition Width="Auto" />
                            <ColumnDefinition Width="76" />
                          </Grid.ColumnDefinitions>

                          <!-- Play/Pause -->
                          <Button Name="BtnMediaPlayPause" Grid.Column="0" Style="{StaticResource MediaControlButtonStyle}" Width="30" Height="26" ToolTip="Play / Pause (Space or Click video)">
                            <TextBlock Name="TxtMediaPlayIcon" Text="&#xE768;" FontFamily="Segoe MDL2 Assets" FontSize="12" Foreground="#c15f3c" />
                          </Button>

                          <!-- Stop -->
                          <Button Name="BtnMediaStop" Grid.Column="1" Style="{StaticResource MediaControlButtonStyle}" Width="28" Height="26" Margin="4,0,0,0" ToolTip="Stop playback">
                            <TextBlock Text="&#xE71A;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#A1A1AA" />
                          </Button>

                          <!-- Rewind -5s -->
                          <Button Name="BtnMediaRewind" Grid.Column="2" Style="{StaticResource MediaControlButtonStyle}" Width="28" Height="26" Margin="4,0,0,0" ToolTip="Skip back 5 seconds">
                            <TextBlock Text="&#xEB9E;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#A1A1AA" />
                          </Button>

                          <!-- Forward +5s -->
                          <Button Name="BtnMediaForward" Grid.Column="3" Style="{StaticResource MediaControlButtonStyle}" Width="28" Height="26" Margin="4,0,0,0" ToolTip="Skip forward 5 seconds">
                            <TextBlock Text="&#xEB9D;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#A1A1AA" />
                          </Button>

                          <!-- Open in default player -->
                          <Button Name="BtnMediaOpenExternal" Grid.Column="5" Style="{StaticResource MediaControlButtonStyle}" Width="28" Height="26" Margin="0,0,6,0" ToolTip="Open in Default Player / VLC">
                            <TextBlock Text="&#xE8A7;" FontFamily="Segoe MDL2 Assets" FontSize="11.5" Foreground="#38BDF8" />
                          </Button>

                          <!-- Mute button -->
                          <Button Name="BtnMediaMute" Grid.Column="6" Style="{StaticResource MediaControlButtonStyle}" Width="28" Height="26" Margin="0,0,4,0" ToolTip="Mute / Unmute">
                            <TextBlock Name="TxtMediaMuteIcon" Text="&#xE767;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#A1A1AA" />
                          </Button>

                          <!-- Volume Slider -->
                          <Slider Name="SliderMediaVolume" Grid.Column="7" Minimum="0" Maximum="1" Value="0.75" IsMoveToPointEnabled="True" VerticalAlignment="Center" Height="18" Cursor="Hand" Style="{StaticResource DarkObsidianSliderStyle}" ToolTip="Volume" />
                        </Grid>
                      </StackPanel>
                    </Border>
                  </Grid>

                  <!-- Universal Text & Code Preview & On-Demand Editor -->
                  <Grid Name="PanelPreviewText" Visibility="Collapsed">
                    <Grid.RowDefinitions>
                      <RowDefinition Height="Auto" />
                      <RowDefinition Height="*" />
                    </Grid.RowDefinitions>

                    <Border Grid.Row="0" Background="#16161C" BorderBrush="#23232A" BorderThickness="1" CornerRadius="4" Padding="8,4" Margin="0,0,0,6">
                      <Grid>
                        <Grid.ColumnDefinitions>
                          <ColumnDefinition Width="Auto" />
                          <ColumnDefinition Width="*" />
                          <ColumnDefinition Width="Auto" />
                          <ColumnDefinition Width="Auto" />
                        </Grid.ColumnDefinitions>

                        <!-- Language Badge -->
                        <Border Grid.Column="0" Background="#23232A" CornerRadius="3" Padding="6,2">
                          <TextBlock Name="TxtCodeLanguage" Text="CODE" FontSize="9" FontWeight="Bold" Foreground="#c15f3c" />
                        </Border>

                        <!-- Line Count & File Size -->
                        <TextBlock Name="TxtCodeLineCount" Grid.Column="2" Text="0 lines" FontSize="9.5" Foreground="#71717A" VerticalAlignment="Center" Margin="0,0,10,0" />

                        <!-- Right: Actions Container -->
                        <StackPanel Grid.Column="3" Orientation="Horizontal" VerticalAlignment="Center">
                          <!-- 1. Default Read-Only Mode: Edit Button -->
                          <Button Name="BtnEditTextPreview" Style="{StaticResource QuickPillButton}" Height="24" Padding="10,0" Background="#181820" BorderBrush="#2A2B36" Foreground="#E4E4E7" Cursor="Hand" ToolTip="Click to edit this file">
                            <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                              <TextBlock Text="&#xE70F;" FontFamily="Segoe MDL2 Assets" FontSize="10" Foreground="#c15f3c" Margin="0,0,5,0" VerticalAlignment="Center" />
                              <TextBlock Text="Edit" FontSize="10.5" FontWeight="SemiBold" Foreground="#F5EDE0" VerticalAlignment="Center" />
                            </StackPanel>
                          </Button>

                          <!-- 2. Edit Mode Actions: Save & Cancel -->
                          <StackPanel Name="PanelEditActions" Orientation="Horizontal" VerticalAlignment="Center" Visibility="Collapsed">
                            <!-- Save Button -->
                            <Button Name="BtnSaveTextPreview" Style="{StaticResource QuickPillButton}" Height="24" Padding="10,0" Background="#2A1710" BorderBrush="#c15f3c" Foreground="#FFFFFF" Cursor="Hand" ToolTip="Save changes to file (Ctrl+S)" Margin="0,0,6,0">
                              <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                <TextBlock Text="&#xE74E;" FontFamily="Segoe MDL2 Assets" FontSize="10" Foreground="#c15f3c" Margin="0,0,5,0" VerticalAlignment="Center" />
                                <TextBlock Text="Save" FontSize="10.5" FontWeight="Bold" Foreground="#FFFFFF" VerticalAlignment="Center" />
                              </StackPanel>
                            </Button>
                            <!-- Cancel Button -->
                            <Button Name="BtnCancelEditTextPreview" Style="{StaticResource QuickPillButton}" Height="24" Padding="9,0" Background="#181820" BorderBrush="#2A2B36" Foreground="#A1A1AA" Cursor="Hand" ToolTip="Cancel editing without saving (Esc)">
                              <TextBlock Text="Cancel" FontSize="10.5" FontWeight="SemiBold" Foreground="#A1A1AA" VerticalAlignment="Center" />
                            </Button>
                          </StackPanel>
                        </StackPanel>
                      </Grid>
                    </Border>

                    <Border Grid.Row="1" Background="#0C0D11" BorderBrush="#23232A" BorderThickness="1" CornerRadius="6" Padding="2">
                      <RichTextBox Name="TxtPreviewContent" Background="Transparent" Foreground="#D4D4D8" BorderThickness="0" FontFamily="Cascadia Code, Consolas, Courier New" FontSize="11.5" IsReadOnly="True" IsReadOnlyCaretVisible="True" AcceptsReturn="True" AcceptsTab="True" HorizontalScrollBarVisibility="Auto" VerticalScrollBarVisibility="Auto" SelectionBrush="#c15f3c" CaretBrush="#F5EDE0">
                        <RichTextBox.Resources>
                          <Style TargetType="{x:Type Paragraph}">
                            <Setter Property="Margin" Value="0" />
                            <Setter Property="LineHeight" Value="17" />
                          </Style>
                        </RichTextBox.Resources>
                      </RichTextBox>
                    </Border>
                  </Grid>

                  <!-- Binary / Compiled File Inspector -->
                  <Border Name="PanelPreviewBinary" Visibility="Collapsed" Background="#0C0D11" BorderBrush="#23232A" BorderThickness="1" CornerRadius="6" Padding="14">
                    <StackPanel VerticalAlignment="Center" HorizontalAlignment="Center">
                      <Border Width="48" Height="48" Background="#16161C" BorderBrush="#23232A" BorderThickness="1" CornerRadius="24" HorizontalAlignment="Center" Margin="0,0,0,12">
                        <TextBlock Text="&#xE7C3;" FontFamily="Segoe MDL2 Assets" FontSize="20" Foreground="#c15f3c" HorizontalAlignment="Center" VerticalAlignment="Center" />
                      </Border>
                      <TextBlock Name="TxtBinaryTitle" Text="Binary File" FontWeight="Bold" FontSize="12.5" Foreground="#F5EDE0" HorizontalAlignment="Center" TextAlignment="Center" TextWrapping="Wrap" />
                      <TextBlock Name="TxtBinaryType" Text="Application / Binary" FontSize="10.5" Foreground="#A1A1AA" HorizontalAlignment="Center" Margin="0,4,0,0" />
                      <TextBlock Name="TxtBinarySize" Text="0 B" FontSize="10" Foreground="#71717A" HorizontalAlignment="Center" Margin="0,2,0,0" />
                      <TextBlock Name="TxtBinaryDate" Text="Modified: --" FontSize="9.5" Foreground="#52525B" HorizontalAlignment="Center" Margin="0,4,0,0" />
                      <Border Background="#16161C" CornerRadius="4" Padding="8,4" Margin="0,14,0,0" HorizontalAlignment="Center">
                        <TextBlock Text="No preview available for binary format" FontSize="9.5" Foreground="#71717A" />
                      </Border>
                    </StackPanel>
                  </Border>

                  <!-- Directory / Folder Inspector -->
                  <Border Name="PanelPreviewFolder" Visibility="Collapsed" Background="#0C0D11" BorderBrush="#23232A" BorderThickness="1" CornerRadius="6" Padding="14">
                    <StackPanel VerticalAlignment="Center" HorizontalAlignment="Center">
                      <Border Width="56" Height="56" Background="#16161C" BorderBrush="#23232A" BorderThickness="1" CornerRadius="12" HorizontalAlignment="Center" Margin="0,0,0,12">
                        <Image Name="ImgFolderPreviewIcon" Width="40" Height="40" Stretch="Uniform" RenderOptions.BitmapScalingMode="HighQuality" HorizontalAlignment="Center" VerticalAlignment="Center" />
                      </Border>
                      <TextBlock Name="TxtFolderTitle" Text="Folder" FontWeight="Bold" FontSize="12.5" Foreground="#F5EDE0" HorizontalAlignment="Center" TextAlignment="Center" TextWrapping="Wrap" />
                      <TextBlock Text="File Folder" FontSize="10.5" Foreground="#A1A1AA" HorizontalAlignment="Center" Margin="0,4,0,0" />
                      <TextBlock Name="TxtFolderSize" Text="Size: --" FontSize="10" Foreground="#71717A" HorizontalAlignment="Center" Margin="0,2,0,0" />
                      <TextBlock Name="TxtFolderModified" Text="Modified: --" FontSize="9.5" Foreground="#52525B" HorizontalAlignment="Center" Margin="0,4,0,0" />
                    </StackPanel>
                  </Border>
                </Grid>

                <!-- Preview Footer Metadata -->
                <Border Grid.Row="2" Background="#16161C" BorderBrush="#23232A" BorderThickness="0,1,0,0" CornerRadius="0,0,8,8" Padding="12,10">
                  <StackPanel>
                    <TextBlock Name="TxtPreviewFileName" FontWeight="Bold" FontSize="11.5" Foreground="#F5EDE0" TextTrimming="CharacterEllipsis" />
                    <TextBlock Name="TxtPreviewMetaDetails" FontSize="10" Foreground="#94A3B8" Margin="0,3,0,0" TextTrimming="CharacterEllipsis" />
                  </StackPanel>
                </Border>
              </Grid>
            </Border>
          </Grid>
        </Grid>

        <!-- VIEW 2: FULL ABOUT & INFORMATION SCREEN -->
        <ScrollViewer Name="ViewAbout" Visibility="Collapsed" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="28,20,28,28" Background="#0C0C0F">
          <StackPanel MaxWidth="920" HorizontalAlignment="Stretch">
            <!-- Hero Header Banner -->
            <Border Background="#111114" BorderBrush="#23232A" BorderThickness="1" CornerRadius="8" Padding="22,18" Margin="0,0,0,14">
              <Grid>
                <Grid.ColumnDefinitions>
                  <ColumnDefinition Width="Auto" />
                  <ColumnDefinition Width="*" />
                </Grid.ColumnDefinitions>
                
                <!-- Logo Frame -->
                <Border Grid.Column="0" Name="BtnAboutLogo" CornerRadius="8" Width="64" Height="64" Margin="0,0,18,0" Background="#18181C" BorderBrush="#2A2B36" BorderThickness="1" VerticalAlignment="Center" Cursor="Hand" ToolTip="Visit zeroiq.site">
                  <Grid>
                    <Image Name="ImgAboutLogo" Width="56" Height="56" RenderOptions.BitmapScalingMode="HighQuality" Stretch="Uniform" />
                    <TextBlock Name="TxtAboutFallbackLogo" Text="&#xEC50;" FontFamily="Segoe MDL2 Assets" FontSize="26" Foreground="#38BDF8" HorizontalAlignment="Center" VerticalAlignment="Center" />
                  </Grid>
                </Border>

                <!-- Title, Badges & Subtitle -->
                <StackPanel Grid.Column="1" VerticalAlignment="Center">
                  <StackPanel Orientation="Horizontal" VerticalAlignment="Center" Margin="0,0,0,6">
                    <TextBlock Text="Zero" FontSize="22" FontWeight="Bold" Foreground="#c15f3c" />
                    <TextBlock Text="Explore" FontSize="22" FontWeight="Bold" Foreground="#F5EDE0" Margin="0,0,12,0" />
                    <!-- Version Badge -->
                    <Border Background="#18181C" BorderBrush="#23232A" BorderThickness="1" CornerRadius="5" Padding="8,2" Margin="0,0,6,0">
                      <TextBlock Text="v1.0.2" FontSize="10" FontWeight="Bold" Foreground="#F5EDE0" VerticalAlignment="Center" />
                    </Border>
                    <!-- GPLv3 Badge -->
                    <Border Background="#18181C" BorderBrush="#23232A" BorderThickness="1" CornerRadius="5" Padding="8,2" Margin="0,0,6,0">
                      <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                        <TextBlock Text="&#xE72D;" FontFamily="Segoe MDL2 Assets" FontSize="9.5" Foreground="#c15f3c" Margin="0,0,5,0" VerticalAlignment="Center" />
                        <TextBlock Text="GPLv3 Open Source" FontSize="10" FontWeight="SemiBold" Foreground="#D4D4D8" VerticalAlignment="Center" />
                      </StackPanel>
                    </Border>
                    <!-- Windows 10 / 11 Badge -->
                    <Border Background="#14261B" BorderBrush="#235E35" BorderThickness="1" CornerRadius="5" Padding="8,2">
                      <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                        <TextBlock Text="&#xE782;" FontFamily="Segoe MDL2 Assets" FontSize="10" Foreground="#4ADE80" Margin="0,0,5,0" VerticalAlignment="Center" />
                        <TextBlock Text="Windows 10 / 11" FontSize="10" FontWeight="Bold" Foreground="#4ADE80" VerticalAlignment="Center" />
                      </StackPanel>
                    </Border>
                  </StackPanel>
                  <TextBlock Text="Fast, lightweight, and resource-conscious file manager &amp; media inspector." FontSize="11.5" Foreground="#94A3B8" />
                </StackPanel>
              </Grid>
            </Border>

            <!-- Minimal Update Row -->
            <Border Background="#111114" BorderBrush="#202026" BorderThickness="1" CornerRadius="6" Padding="12,7" Margin="0,0,0,14">
              <DockPanel LastChildFill="False">
                <StackPanel Orientation="Horizontal" DockPanel.Dock="Left" VerticalAlignment="Center">
                  <TextBlock Text="&#xE72C;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#c15f3c" Margin="0,0,7,0" VerticalAlignment="Center" />
                  <TextBlock Name="TxtAppUpdateStatus" Text="Up to date (v1.0.2)" FontSize="11" FontWeight="SemiBold" Foreground="#4ADE80" VerticalAlignment="Center" />
                </StackPanel>
                <StackPanel Orientation="Horizontal" DockPanel.Dock="Right" VerticalAlignment="Center">
                  <Button Name="BtnManualCheckUpdates" Style="{StaticResource b2}" Background="#16161A" Foreground="#D4D4D8" Content="Check for Updates" Height="24" Padding="10,0" FontSize="10" FontWeight="SemiBold" Cursor="Hand" Margin="0,0,6,0" />
                  <Button Name="BtnAppUpdateTab" Style="{StaticResource b2}" Background="#c15f3c" Foreground="#FFFFFF" Content="Install Update" Height="24" Padding="12,0" FontSize="10" FontWeight="Bold" Cursor="Hand" Visibility="Collapsed" />
                </StackPanel>
              </DockPanel>
            </Border>

            <!-- What This App Does (Features & Architecture Grid) -->
            <TextBlock Text="WHAT ZEROEXPLORE DOES" FontSize="9.5" FontWeight="Bold" Foreground="#c15f3c" Margin="2,0,0,8" />
            <UniformGrid Columns="3" Margin="0,0,0,14">
              <!-- Feature 1: Drive Navigation -->
              <Border Background="#111114" BorderBrush="#23232A" BorderThickness="1" CornerRadius="6" Padding="14,12" Margin="3">
                <StackPanel>
                  <StackPanel Orientation="Horizontal" Margin="0,0,0,6">
                    <Border Background="#211512" BorderBrush="#4A251C" BorderThickness="1" CornerRadius="4" Width="24" Height="24" Margin="0,0,8,0">
                      <TextBlock Text="&#xEDA2;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#c15f3c" HorizontalAlignment="Center" VerticalAlignment="Center" />
                    </Border>
                    <TextBlock Text="Drive &amp; Partition Browsing" FontWeight="Bold" FontSize="11.5" Foreground="#F5EDE0" VerticalAlignment="Center" />
                  </StackPanel>
                  <TextBlock Text="Instant switching between all local drives with real-time storage metrics (free/used/total space) and fast path jump bar." FontSize="10.5" Foreground="#94A3B8" TextWrapping="Wrap" />
                </StackPanel>
              </Border>
              <!-- Feature 2: Side Previewer -->
              <Border Background="#111114" BorderBrush="#23232A" BorderThickness="1" CornerRadius="6" Padding="14,12" Margin="3">
                <StackPanel>
                  <StackPanel Orientation="Horizontal" Margin="0,0,0,6">
                    <Border Background="#121D28" BorderBrush="#1C3854" BorderThickness="1" CornerRadius="4" Width="24" Height="24" Margin="0,0,8,0">
                      <TextBlock Text="&#xE890;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#38BDF8" HorizontalAlignment="Center" VerticalAlignment="Center" />
                    </Border>
                    <TextBlock Text="Live File &amp; Media Preview" FontWeight="Bold" FontSize="11.5" Foreground="#F5EDE0" VerticalAlignment="Center" />
                  </StackPanel>
                  <TextBlock Text="Integrated side pane for video playback, audio waveform playing, high-res image zoom, and code viewing without external tools." FontSize="10.5" Foreground="#94A3B8" TextWrapping="Wrap" />
                </StackPanel>
              </Border>
              <!-- Feature 3: File Transfers -->
              <Border Background="#111114" BorderBrush="#23232A" BorderThickness="1" CornerRadius="6" Padding="14,12" Margin="3">
                <StackPanel>
                  <StackPanel Orientation="Horizontal" Margin="0,0,0,6">
                    <Border Background="#132218" BorderBrush="#204A30" BorderThickness="1" CornerRadius="4" Width="24" Height="24" Margin="0,0,8,0">
                      <TextBlock Text="&#xE77F;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#4ADE80" HorizontalAlignment="Center" VerticalAlignment="Center" />
                    </Border>
                    <TextBlock Text="Natural Copy, Cut &amp; Paste" FontWeight="Bold" FontSize="11.5" Foreground="#F5EDE0" VerticalAlignment="Center" />
                  </StackPanel>
                  <TextBlock Text="Direct clipboard file operations with automatic collision numbering ('File - Copy'), multi-selection support, and Ctrl+C/X/V." FontSize="10.5" Foreground="#94A3B8" TextWrapping="Wrap" />
                </StackPanel>
              </Border>
              <!-- Feature 4: Async Sizing -->
              <Border Background="#111114" BorderBrush="#23232A" BorderThickness="1" CornerRadius="6" Padding="14,12" Margin="3">
                <StackPanel>
                  <StackPanel Orientation="Horizontal" Margin="0,0,0,6">
                    <Border Background="#12241F" BorderBrush="#1C473A" BorderThickness="1" CornerRadius="4" Width="24" Height="24" Margin="0,0,8,0">
                      <TextBlock Text="&#xE9D9;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#34D399" HorizontalAlignment="Center" VerticalAlignment="Center" />
                    </Border>
                    <TextBlock Text="Non-Blocking Folder Sizing" FontWeight="Bold" FontSize="11.5" Foreground="#F5EDE0" VerticalAlignment="Center" />
                  </StackPanel>
                  <TextBlock Text="Calculates exact folder sizes recursively in the background without locking the user interface or stuttering folder navigation." FontSize="10.5" Foreground="#94A3B8" TextWrapping="Wrap" />
                </StackPanel>
              </Border>
              <!-- Feature 5: Quick Locations -->
              <Border Background="#111114" BorderBrush="#23232A" BorderThickness="1" CornerRadius="6" Padding="14,12" Margin="3">
                <StackPanel>
                  <StackPanel Orientation="Horizontal" Margin="0,0,0,6">
                    <Border Background="#1F162A" BorderBrush="#3D2956" BorderThickness="1" CornerRadius="4" Width="24" Height="24" Margin="0,0,8,0">
                      <TextBlock Text="&#xE71B;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#A78BFA" HorizontalAlignment="Center" VerticalAlignment="Center" />
                    </Border>
                    <TextBlock Text="Quick Jump Locations" FontWeight="Bold" FontSize="11.5" Foreground="#F5EDE0" VerticalAlignment="Center" />
                  </StackPanel>
                  <TextBlock Text="Fast access to Downloads, Documents, AppData, and Temp folders, plus custom pinning of favorite project folders." FontSize="10.5" Foreground="#94A3B8" TextWrapping="Wrap" />
                </StackPanel>
              </Border>
              <!-- Feature 6: Terminal & Shell -->
              <Border Background="#111114" BorderBrush="#23232A" BorderThickness="1" CornerRadius="6" Padding="14,12" Margin="3">
                <StackPanel>
                  <StackPanel Orientation="Horizontal" Margin="0,0,0,6">
                    <Border Background="#251F10" BorderBrush="#4E3E1A" BorderThickness="1" CornerRadius="4" Width="24" Height="24" Margin="0,0,8,0">
                      <TextBlock Text="&#xE756;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#F59E0B" HorizontalAlignment="Center" VerticalAlignment="Center" />
                    </Border>
                    <TextBlock Text="Terminal &amp; Shell Tools" FontWeight="Bold" FontSize="11.5" Foreground="#F5EDE0" VerticalAlignment="Center" />
                  </StackPanel>
                  <TextBlock Text="One-click launch of Windows Terminal, PowerShell, or File Explorer directly inside the currently active directory." FontSize="10.5" Foreground="#94A3B8" TextWrapping="Wrap" />
                </StackPanel>
              </Border>
            </UniformGrid>

            <!-- System & Runtime Environment Telemetry -->
            <Border Background="#111114" BorderBrush="#23232A" BorderThickness="1" CornerRadius="8" Padding="18,14" Margin="0,0,0,14">
              <StackPanel>
                <TextBlock Text="SYSTEM &amp; RUNTIME ENVIRONMENT" FontSize="9.5" FontWeight="Bold" Foreground="#c15f3c" Margin="0,0,0,10" />
                <UniformGrid Columns="4">
                  <Border Background="#15151A" BorderBrush="#202028" BorderThickness="1" CornerRadius="6" Padding="12,10" Margin="3">
                    <StackPanel>
                      <TextBlock Text="HOST DEVICE" FontSize="9" FontWeight="Bold" Foreground="#71717A" />
                      <TextBlock Name="TxtAboutMachine" Text="Windows PC" FontSize="11.5" FontWeight="SemiBold" Foreground="#F5EDE0" Margin="0,3,0,0" />
                    </StackPanel>
                  </Border>
                  <Border Background="#15151A" BorderBrush="#202028" BorderThickness="1" CornerRadius="6" Padding="12,10" Margin="3">
                    <StackPanel>
                      <TextBlock Text="OPERATING SYSTEM" FontSize="9" FontWeight="Bold" Foreground="#71717A" />
                      <TextBlock Name="TxtAboutOS" Text="Windows 10 Pro" FontSize="11.5" FontWeight="Bold" Foreground="#4ADE80" Margin="0,3,0,0" />
                      <TextBlock Name="TxtAboutOSVersion" Text="Version 22H2 &#x2022; Build 19045.7058" FontSize="9" Foreground="#94A3B8" Margin="0,2,0,0" />
                    </StackPanel>
                  </Border>
                  <Border Background="#15151A" BorderBrush="#202028" BorderThickness="1" CornerRadius="6" Padding="12,10" Margin="3">
                    <StackPanel>
                      <TextBlock Text="POWERSHELL RUNTIME" FontSize="9" FontWeight="Bold" Foreground="#71717A" />
                      <TextBlock Name="TxtAboutPS" Text="PS 5.1 Desktop STA" FontSize="11.5" FontWeight="SemiBold" Foreground="#F5EDE0" Margin="0,3,0,0" />
                    </StackPanel>
                  </Border>
                  <Border Background="#15151A" BorderBrush="#202028" BorderThickness="1" CornerRadius="6" Padding="12,10" Margin="3">
                    <StackPanel>
                      <TextBlock Text="PHYSICAL MEMORY" FontSize="9" FontWeight="Bold" Foreground="#71717A" />
                      <TextBlock Name="TxtAboutRAM" Text="System RAM" FontSize="11.5" FontWeight="SemiBold" Foreground="#38BDF8" Margin="0,3,0,0" />
                    </StackPanel>
                  </Border>
                </UniformGrid>
              </StackPanel>
            </Border>

            <!-- Other Projects Section -->
            <TextBlock Text="OTHER PROJECTS BY ZEROIQ" FontSize="9.5" FontWeight="Bold" Foreground="#c15f3c" Margin="2,0,0,8" />
            <UniformGrid Columns="3" Margin="0,0,0,14">
              <!-- Project 1: ZeroHub -->
              <Border Background="#111114" BorderBrush="#23232A" BorderThickness="1" CornerRadius="8" Padding="14,12" Margin="3">
                <Grid>
                  <Grid.RowDefinitions>
                    <RowDefinition Height="Auto" />
                    <RowDefinition Height="*" />
                    <RowDefinition Height="Auto" />
                  </Grid.RowDefinitions>
                  <StackPanel Grid.Row="0" Orientation="Horizontal" Margin="0,0,0,6">
                    <Border Background="#251612" BorderBrush="#4D281E" BorderThickness="1" CornerRadius="5" Width="26" Height="26" Margin="0,0,8,0">
                      <TextBlock Text="&#xE770;" FontFamily="Segoe MDL2 Assets" FontSize="12" Foreground="#c15f3c" HorizontalAlignment="Center" VerticalAlignment="Center" />
                    </Border>
                    <TextBlock Text="ZeroHub" FontWeight="Bold" FontSize="12" Foreground="#F5EDE0" VerticalAlignment="Center" />
                  </StackPanel>
                  <TextBlock Grid.Row="1" Text="Comprehensive Windows optimization engine, telemetry controller, and debloating toolkit." FontSize="10.5" Foreground="#94A3B8" TextWrapping="Wrap" Margin="0,0,0,10" />
                  <Button Grid.Row="2" Name="BtnProjectZeroHub" Style="{StaticResource b2}" Background="#161720" Foreground="#D4D4D8" Height="26" Padding="10,0" Cursor="Hand" ToolTip="https://github.com/ZeroIQs/Zerohub">
                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                      <Path Data="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z" Fill="#D4D4D8" Stretch="Uniform" Width="11" Height="11" Margin="0,0,5,0" VerticalAlignment="Center" />
                      <TextBlock Text="GitHub Repo" FontWeight="SemiBold" FontSize="10.5" Foreground="#D4D4D8" VerticalAlignment="Center" />
                    </StackPanel>
                  </Button>
                </Grid>
              </Border>

              <!-- Project 2: ExPDF -->
              <Border Background="#111114" BorderBrush="#23232A" BorderThickness="1" CornerRadius="8" Padding="14,12" Margin="3">
                <Grid>
                  <Grid.RowDefinitions>
                    <RowDefinition Height="Auto" />
                    <RowDefinition Height="*" />
                    <RowDefinition Height="Auto" />
                  </Grid.RowDefinitions>
                  <StackPanel Grid.Row="0" Orientation="Horizontal" Margin="0,0,0,6">
                    <Border Background="#121D28" BorderBrush="#1C3854" BorderThickness="1" CornerRadius="5" Width="26" Height="26" Margin="0,0,8,0">
                      <TextBlock Text="&#xE8A5;" FontFamily="Segoe MDL2 Assets" FontSize="12" Foreground="#38BDF8" HorizontalAlignment="Center" VerticalAlignment="Center" />
                    </Border>
                    <TextBlock Text="ExPDF" FontWeight="Bold" FontSize="12" Foreground="#F5EDE0" VerticalAlignment="Center" />
                  </StackPanel>
                  <TextBlock Grid.Row="1" Text="Fast, client-side PDF extractor, merger, page organizer, and document modifier." FontSize="10.5" Foreground="#94A3B8" TextWrapping="Wrap" Margin="0,0,0,10" />
                  <Button Grid.Row="2" Name="BtnProjectExPDF" Style="{StaticResource b2}" Background="#161720" Foreground="#D4D4D8" Height="26" Padding="10,0" Cursor="Hand" ToolTip="https://expdf.space/">
                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                      <TextBlock Text="&#xE774;" FontFamily="Segoe MDL2 Assets" FontSize="10.5" Foreground="#38BDF8" Margin="0,0,5,0" VerticalAlignment="Center" />
                      <TextBlock Text="expdf.space" FontWeight="SemiBold" FontSize="10.5" Foreground="#D4D4D8" VerticalAlignment="Center" />
                    </StackPanel>
                  </Button>
                </Grid>
              </Border>

              <!-- Project 3: ZeroIQ Wallpapers -->
              <Border Background="#111114" BorderBrush="#23232A" BorderThickness="1" CornerRadius="8" Padding="14,12" Margin="3">
                <Grid>
                  <Grid.RowDefinitions>
                    <RowDefinition Height="Auto" />
                    <RowDefinition Height="*" />
                    <RowDefinition Height="Auto" />
                  </Grid.RowDefinitions>
                  <StackPanel Grid.Row="0" Orientation="Horizontal" Margin="0,0,0,6">
                    <Border Background="#211526" BorderBrush="#432454" BorderThickness="1" CornerRadius="5" Width="26" Height="26" Margin="0,0,8,0">
                      <TextBlock Text="&#xEB9F;" FontFamily="Segoe MDL2 Assets" FontSize="12" Foreground="#C084FC" HorizontalAlignment="Center" VerticalAlignment="Center" />
                    </Border>
                    <TextBlock Text="ZeroIQ Wallpapers" FontWeight="Bold" FontSize="12" Foreground="#F5EDE0" VerticalAlignment="Center" />
                  </StackPanel>
                  <TextBlock Grid.Row="1" Text="Curated gallery of high-resolution, aesthetic minimalist and dark desktop wallpapers." FontSize="10.5" Foreground="#94A3B8" TextWrapping="Wrap" Margin="0,0,0,10" />
                  <Button Grid.Row="2" Name="BtnProjectWallpapers" Style="{StaticResource b2}" Background="#161720" Foreground="#D4D4D8" Height="26" Padding="10,0" Cursor="Hand" ToolTip="https://zeroiqs.github.io/ZeroIQ-Wallpapers/">
                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                      <TextBlock Text="&#xEB9D;" FontFamily="Segoe MDL2 Assets" FontSize="10.5" Foreground="#C084FC" Margin="0,0,5,0" VerticalAlignment="Center" />
                      <TextBlock Text="View Gallery" FontWeight="SemiBold" FontSize="10.5" Foreground="#D4D4D8" VerticalAlignment="Center" />
                    </StackPanel>
                  </Button>
                </Grid>
              </Border>
            </UniformGrid>

            <!-- Project & Developer Attribution Card (At Bottom) -->
            <Border Background="#111114" BorderBrush="#23232A" BorderThickness="1" CornerRadius="8" Padding="20,16" Margin="0,0,0,6">
              <Grid>
                <Grid.ColumnDefinitions>
                  <ColumnDefinition Width="*" />
                  <ColumnDefinition Width="Auto" />
                </Grid.ColumnDefinitions>
                <StackPanel Grid.Column="0" VerticalAlignment="Center" Margin="0,0,16,0">
                  <TextBlock Text="PROJECT ATTRIBUTION" FontSize="9.5" FontWeight="Bold" Foreground="#c15f3c" Margin="0,0,0,5" />
                  <TextBlock Text="Developed by Amir Ali (ZeroIQ)" FontSize="13.5" FontWeight="Bold" Foreground="#F5EDE0" />
                  <TextBlock Text="Built as an independent, lightweight file explorer focused on rapid folder browsing, directory analysis, and instant media previews." FontSize="11" Foreground="#94A3B8" Margin="0,3,0,0" TextWrapping="Wrap" />
                </StackPanel>
                <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                  <!-- GitHub Button with Official Octocat SVG -->
                  <Button Name="BtnAboutGithub" Style="{StaticResource b2}" Background="#161720" Foreground="#F5EDE0" Height="26" Padding="12,0" Margin="0,0,8,0" Cursor="Hand" ToolTip="GitHub: https://github.com/ZeroIQs">
                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                      <Path Data="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z" Fill="#F5EDE0" Stretch="Uniform" Width="13" Height="13" Margin="0,0,7,0" VerticalAlignment="Center" />
                      <TextBlock Text="GitHub" FontWeight="SemiBold" FontSize="11" Foreground="#F5EDE0" VerticalAlignment="Center" />
                    </StackPanel>
                  </Button>
                  <!-- Website Button -->
                  <Button Name="BtnAboutWebsite" Style="{StaticResource b2}" Background="#161720" Foreground="#D4D4D8" Height="26" Padding="12,0" Margin="0,0,8,0" Cursor="Hand" ToolTip="Visit zeroiq.site">
                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                      <TextBlock Text="&#xE774;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#4ADE80" Margin="0,0,6,0" VerticalAlignment="Center" />
                      <TextBlock Text="zeroiq.site" FontWeight="SemiBold" FontSize="11" Foreground="#D4D4D8" />
                    </StackPanel>
                  </Button>
                  <!-- Donate / Sponsor Button -->
                  <Button Name="BtnAboutDonate" Style="{StaticResource b2}" Background="#161720" Foreground="#D4D4D8" Height="26" Padding="12,0" Cursor="Hand" ToolTip="Donate / Sponsor development">
                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                      <TextBlock Text="&#xEB51;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#c15f3c" Margin="0,0,6,0" VerticalAlignment="Center" />
                      <TextBlock Text="Donate" FontWeight="SemiBold" FontSize="11" Foreground="#D4D4D8" />
                    </StackPanel>
                  </Button>
                </StackPanel>
              </Grid>
            </Border>
          </StackPanel>
        </ScrollViewer>
      </Grid>
    </Grid>

    <!-- Row 2: Status Bar (Fixed 36px height so footer size is stable and UI never shifts) -->
    <Border Grid.Row="2" Height="36" Background="#0C0C0F" BorderBrush="#1C1C22" BorderThickness="0,1,0,0" Padding="14,0">
      <DockPanel LastChildFill="True">
        <StackPanel DockPanel.Dock="Left" Orientation="Horizontal" VerticalAlignment="Center">
          <TextBlock Name="TxtExplorerStatusCount" Text="0 items" FontSize="11" Foreground="#94A3B8" Margin="0,0,16,0" VerticalAlignment="Center" />
          <TextBlock Name="TxtExplorerSelectedInfo" Text="" FontSize="11" Foreground="#c15f3c" FontWeight="SemiBold" VerticalAlignment="Center" />
        </StackPanel>
        <StackPanel DockPanel.Dock="Right" Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
          <TextBlock Name="TxtTransferStatus" Text="" FontSize="10.5" Foreground="#4ADE80" VerticalAlignment="Center" Margin="0,0,10,0" MaxWidth="450" TextTrimming="CharacterEllipsis" />

          <!-- Live Transfer Progress Indicator & Bar (Flush bottom-right) -->
          <Border Name="PanelTransferProgress" Visibility="Collapsed" Background="#14141A" BorderBrush="#23232A" BorderThickness="1" CornerRadius="5" Padding="8,3" Height="26" VerticalAlignment="Center">
            <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
              <!-- Action Icon -->
              <TextBlock Name="IconTransferProgress" Text="&#xE896;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#c15f3c" Margin="0,0,6,0" VerticalAlignment="Center" />
              <!-- Operation & File Name -->
              <TextBlock Name="TxtTransferAction" Text="Copying..." FontSize="10" FontWeight="SemiBold" Foreground="#F5EDE0" MaxWidth="190" TextTrimming="CharacterEllipsis" VerticalAlignment="Center" Margin="0,0,8,0" />
              <!-- Progress Bar -->
              <Border Background="#140F0C" CornerRadius="3" Height="6" Width="140" SnapsToDevicePixels="True" VerticalAlignment="Center">
                <ProgressBar Name="ProgBarTransfer" Minimum="0" Maximum="100" Value="0" Height="6" Foreground="#c15f3c" Background="Transparent" BorderThickness="0" />
              </Border>
              <!-- Percentage Text -->
              <TextBlock Name="TxtTransferPercent" Text="0%" FontSize="10" FontWeight="Bold" Foreground="#c15f3c" Width="36" TextAlignment="Right" VerticalAlignment="Center" Margin="6,0,0,0" />
            </StackPanel>
          </Border>
        </StackPanel>
      </DockPanel>
    </Border>
  </Grid>
</Window>
'@

# Read and Load Window
$reader  = New-Object System.Xml.XmlNodeReader $xaml
$Window  = [System.Windows.Markup.XamlReader]::Load($reader)

# Map UI Controls
$BtnAddToDesktop        = $Window.FindName("BtnAddToDesktop")
$BtnWindowMin           = $Window.FindName("BtnWindowMin")
$BtnWindowMax           = $Window.FindName("BtnWindowMax")
$BtnWindowClose         = $Window.FindName("BtnWindowClose")
$TxtMaxIcon             = $Window.FindName("TxtMaxIcon")
$BtnHeaderLogo          = $Window.FindName("BtnHeaderLogo")
$ImgHeaderLogo          = $Window.FindName("ImgHeaderLogo")
$TxtHeaderFallbackLogo  = $Window.FindName("TxtHeaderFallbackLogo")

# Sidebar Controls
$PanelExplorerDriveButtons = $Window.FindName("PanelExplorerDriveButtons")
$TxtDriveCountBadge     = $Window.FindName("TxtDriveCountBadge")

$BtnQuickDesktop        = $Window.FindName("BtnQuickDesktop")
$Border_Quick_Desktop   = $Window.FindName("Border_Quick_Desktop")
$Icon_Quick_Desktop     = $Window.FindName("Icon_Quick_Desktop")
$Txt_Quick_Desktop      = $Window.FindName("Txt_Quick_Desktop")

$BtnQuickDownloads      = $Window.FindName("BtnQuickDownloads")
$Border_Quick_Downloads = $Window.FindName("Border_Quick_Downloads")
$Icon_Quick_Downloads   = $Window.FindName("Icon_Quick_Downloads")
$Txt_Quick_Downloads    = $Window.FindName("Txt_Quick_Downloads")

$BtnQuickDocuments      = $Window.FindName("BtnQuickDocuments")
$Border_Quick_Documents = $Window.FindName("Border_Quick_Documents")
$Icon_Quick_Documents   = $Window.FindName("Icon_Quick_Documents")
$Txt_Quick_Documents    = $Window.FindName("Txt_Quick_Documents")

$BtnQuickAppData        = $Window.FindName("BtnQuickAppData")
$Border_Quick_AppData   = $Window.FindName("Border_Quick_AppData")
$Icon_Quick_AppData     = $Window.FindName("Icon_Quick_AppData")
$Txt_Quick_AppData      = $Window.FindName("Txt_Quick_AppData")

$BtnQuickTemp           = $Window.FindName("BtnQuickTemp")
$Border_Quick_Temp      = $Window.FindName("Border_Quick_Temp")
$Icon_Quick_Temp        = $Window.FindName("Icon_Quick_Temp")
$Txt_Quick_Temp         = $Window.FindName("Txt_Quick_Temp")
$BtnQuickRecycleBin     = $Window.FindName("BtnQuickRecycleBin")
$Border_Quick_RecycleBin = $Window.FindName("Border_Quick_RecycleBin")
$Icon_Quick_RecycleBin   = $Window.FindName("Icon_Quick_RecycleBin")
$Txt_Quick_RecycleBin    = $Window.FindName("Txt_Quick_RecycleBin")
$PanelQuickAccessCustom = $Window.FindName("PanelQuickAccessCustom")

$Icon_Nav_About         = $Window.FindName("Icon_Nav_About")
$Txt_Nav_About          = $Window.FindName("Txt_Nav_About")

# Actions & Tools
$BtnCopy                = $Window.FindName("BtnCopy")
$BtnCut                 = $Window.FindName("BtnCut")
$BtnPaste               = $Window.FindName("BtnPaste")
$BadgePasteStatus       = $Window.FindName("BadgePasteStatus")
$TxtPasteBadge          = $Window.FindName("TxtPasteBadge")
$BtnNewFolder           = $Window.FindName("BtnNewFolder")
$BtnNewFile             = $Window.FindName("BtnNewFile")
$BtnTogglePreviewPane   = $Window.FindName("BtnTogglePreviewPane")
$BadgePreviewStatus     = $Window.FindName("BadgePreviewStatus")
$TxtBadgePreviewStatus  = $Window.FindName("TxtBadgePreviewStatus")
$BtnToggleViewMode      = $Window.FindName("BtnToggleViewMode")
$IconViewModeGlyph      = $Window.FindName("IconViewModeGlyph")
$TxtViewModeLabel       = $Window.FindName("TxtViewModeLabel")
$BtnToggleSort          = $Window.FindName("BtnToggleSort")
$IconSortGlyph          = $Window.FindName("IconSortGlyph")
$TxtSortModeLabel       = $Window.FindName("TxtSortModeLabel")
$IconSortDirection      = $Window.FindName("IconSortDirection")
$ExplorerIconGrid       = $Window.FindName("ExplorerIconGrid")
$Nav_About              = $Window.FindName("Nav_About")
$Border_Nav_About       = $Window.FindName("Border_Nav_About")
$BtnSidebarWebsite      = $Window.FindName("BtnSidebarWebsite")
$BtnSidebarDonate       = $Window.FindName("BtnSidebarDonate")
$BorderSidebarUpdate     = $Window.FindName("BorderSidebarUpdate")
$BtnSidebarUpdate        = $Window.FindName("BtnSidebarUpdate")
$IconSidebarUpdate       = $Window.FindName("IconSidebarUpdate")
$TxtSidebarUpdate        = $Window.FindName("TxtSidebarUpdate")
$BadgeSidebarUpdateArrow = $Window.FindName("BadgeSidebarUpdateArrow")

# Context Menu Items (Native Windows Options - Dark Obsidian)
$ExplorerContextMenu    = $Window.FindName("ExplorerContextMenu")
$CtxMenuOpen            = $Window.FindName("CtxMenuOpen")
$CtxMenuOpenAdmin       = $Window.FindName("CtxMenuOpenAdmin")
$CtxSepArchiveTop       = $Window.FindName("CtxSepArchiveTop")
$CtxMenuWinRAROpen      = $Window.FindName("CtxMenuWinRAROpen")
$CtxMenuExtractDialog   = $Window.FindName("CtxMenuExtractDialog")
$CtxMenuExtractHere     = $Window.FindName("CtxMenuExtractHere")
$CtxSepArchiveBottom    = $Window.FindName("CtxSepArchiveBottom")

$ImgWinRar1             = $Window.FindName("ImgWinRar1")
$ImgWinRar2             = $Window.FindName("ImgWinRar2")
$ImgWinRar3             = $Window.FindName("ImgWinRar3")
$CtxMenuOpenWith        = $Window.FindName("CtxMenuOpenWith")
$CtxMenuOpenTerminal    = $Window.FindName("CtxMenuOpenTerminal")
$CtxMenuOpenExplorer    = $Window.FindName("CtxMenuOpenExplorer")
$CtxMenuPinQuick        = $Window.FindName("CtxMenuPinQuick")
$CtxMenuCut             = $Window.FindName("CtxMenuCut")
$CtxMenuCopy            = $Window.FindName("CtxMenuCopy")
$CtxMenuCopyPath        = $Window.FindName("CtxMenuCopyPath")
$CtxMenuPaste           = $Window.FindName("CtxMenuPaste")
$CtxMenuShortcut        = $Window.FindName("CtxMenuShortcut")
$CtxMenuDelete          = $Window.FindName("CtxMenuDelete")
$CtxMenuRename          = $Window.FindName("CtxMenuRename")
$CtxMenuNew             = $Window.FindName("CtxMenuNew")
$CtxMenuNewFolder       = $Window.FindName("CtxMenuNewFolder")
$CtxMenuNewTxt          = $Window.FindName("CtxMenuNewTxt")
$CtxMenuNewPs1          = $Window.FindName("CtxMenuNewPs1")
$CtxMenuNewBat          = $Window.FindName("CtxMenuNewBat")
$CtxMenuRefresh         = $Window.FindName("CtxMenuRefresh")
$CtxMenuProperties      = $Window.FindName("CtxMenuProperties")

# Workstation & Hyprland Tiling Controls
$PanelWorkspaceTabBar    = $Window.FindName("PanelWorkspaceTabBar")
$PanelWorkspaceTabList   = $Window.FindName("PanelWorkspaceTabList")
$BtnNewWorkspaceTab      = $Window.FindName("BtnNewWorkspaceTab")
$BtnToggleHyprlandTiling = $Window.FindName("BtnToggleHyprlandTiling")
$IconTilingGlyph         = $Window.FindName("IconTilingGlyph")
$BadgeTilingStatus       = $Window.FindName("BadgeTilingStatus")
$TxtBadgeTilingStatus    = $Window.FindName("TxtBadgeTilingStatus")
$PanelExplorerSingleView = $Window.FindName("PanelExplorerSingleView")
$PanelTilingHost         = $Window.FindName("PanelTilingHost")

# Views
$ViewExplorerFiles      = $Window.FindName("ViewExplorerFiles")
$ViewAbout              = $Window.FindName("ViewAbout")
$BtnAboutLogo           = $Window.FindName("BtnAboutLogo")
$ImgAboutLogo           = $Window.FindName("ImgAboutLogo")
$TxtAboutFallbackLogo   = $Window.FindName("TxtAboutFallbackLogo")
$BtnAboutWebsite        = $Window.FindName("BtnAboutWebsite")
# $BtnAboutGitHub removed - using $BtnAboutGithub (lowercase h) which matches XAML
$BtnAboutDonate         = $Window.FindName("BtnAboutDonate")
$BtnProjectZeroHub      = $Window.FindName("BtnProjectZeroHub")
$BtnProjectExPDF        = $Window.FindName("BtnProjectExPDF")
$BtnProjectWallpapers   = $Window.FindName("BtnProjectWallpapers")
$BtnAboutGithub         = $Window.FindName("BtnAboutGithub")
$TxtAppUpdateStatus     = $Window.FindName("TxtAppUpdateStatus")
$BtnManualCheckUpdates  = $Window.FindName("BtnManualCheckUpdates")
$BtnAppUpdateTab        = $Window.FindName("BtnAppUpdateTab")
$TxtAboutMachine        = $Window.FindName("TxtAboutMachine")
$TxtAboutOS             = $Window.FindName("TxtAboutOS")
$TxtAboutOSVersion      = $Window.FindName("TxtAboutOSVersion")
$TxtAboutPS             = $Window.FindName("TxtAboutPS")
$TxtAboutRAM            = $Window.FindName("TxtAboutRAM")

# Navigation & Search Controls
$BtnExplorerBack        = $Window.FindName("BtnExplorerBack")
$BtnExplorerForward     = $Window.FindName("BtnExplorerForward")
$BtnExplorerUp          = $Window.FindName("BtnExplorerUp")
$BtnExplorerRefresh     = $Window.FindName("BtnExplorerRefresh")
$BtnExplorerHome        = $Window.FindName("BtnExplorerHome")
$TxtExplorerPath        = $Window.FindName("TxtExplorerPath")
$BtnExplorerGo          = $Window.FindName("BtnExplorerGo")
$TxtExplorerFilter      = $Window.FindName("TxtExplorerFilter")

# Grid & Preview Controls
$ExplorerDataGrid       = $Window.FindName("ExplorerDataGrid")
$ColSplitterPreview     = $Window.FindName("ColSplitterPreview")
$ColPreviewPane         = $Window.FindName("ColPreviewPane")
$PreviewPaneContainer   = $Window.FindName("PreviewPaneContainer")
$BtnHidePreviewPane     = $Window.FindName("BtnHidePreviewPane")

$PanelPreviewEmpty      = $Window.FindName("PanelPreviewEmpty")
$PanelPreviewImage      = $Window.FindName("PanelPreviewImage")
$PreviewImgControl      = $Window.FindName("PreviewImgControl")
$PanelPreviewVideo      = $Window.FindName("PanelPreviewVideo")
$PreviewMediaElement    = $Window.FindName("PreviewMediaElement")
$SliderMediaTimeline    = $Window.FindName("SliderMediaTimeline")
$TxtMediaTime           = $Window.FindName("TxtMediaTimeLabel")
$BtnMediaPlayPause      = $Window.FindName("BtnMediaPlayPause")
$TxtMediaPlayIcon       = $Window.FindName("TxtMediaPlayIcon")
$BtnMediaStop           = $Window.FindName("BtnMediaStop")
$BtnMediaRewind         = $Window.FindName("BtnMediaRewind")
$BtnMediaForward        = $Window.FindName("BtnMediaForward")
$BtnMediaOpenExternal   = $Window.FindName("BtnMediaOpenExternal")
$BtnMediaMute           = $Window.FindName("BtnMediaMute")
$TxtMediaMuteIcon       = $Window.FindName("TxtMediaMuteIcon")
$SliderMediaVolume      = $Window.FindName("SliderMediaVolume")
$BorderVideoContainer   = $Window.FindName("BorderVideoContainer")
$OverlayPlayButton      = $Window.FindName("OverlayPlayButton")
$TxtOverlayPlayGlyph    = $Window.FindName("TxtOverlayPlayGlyph")
$PanelAudioDisplay      = $Window.FindName("PanelAudioDisplay")
$TxtAudioTitle          = $Window.FindName("TxtAudioTitle")
$TxtAudioSub            = $Window.FindName("TxtAudioSub")
$PanelMediaFailed       = $Window.FindName("PanelMediaFailed")
$BtnMediaFailedOpen     = $Window.FindName("BtnMediaFailedOpen")

$PanelPreviewText          = $Window.FindName("PanelPreviewText")
$TxtPreviewContent         = $Window.FindName("TxtPreviewContent")
$BtnEditTextPreview        = $Window.FindName("BtnEditTextPreview")
$PanelEditActions          = $Window.FindName("PanelEditActions")
$BtnSaveTextPreview        = $Window.FindName("BtnSaveTextPreview")
$BtnCancelEditTextPreview  = $Window.FindName("BtnCancelEditTextPreview")
$TxtCodeLanguage           = $Window.FindName("TxtCodeLanguage")
$TxtCodeLineCount          = $Window.FindName("TxtCodeLineCount")
$PanelPreviewBinary     = $Window.FindName("PanelPreviewBinary")
$PanelPreviewFolder     = $Window.FindName("PanelPreviewFolder")
$ImgFolderPreviewIcon   = $Window.FindName("ImgFolderPreviewIcon")
$TxtPreviewFileName     = $Window.FindName("TxtPreviewFileName")
$TxtPreviewMetaDetails  = $Window.FindName("TxtPreviewMetaDetails")

# Status Controls
$TxtExplorerStatusCount = $Window.FindName("TxtExplorerStatusCount")
$TxtExplorerSelectedInfo = $Window.FindName("TxtExplorerSelectedInfo")
$PanelTransferProgress  = $Window.FindName("PanelTransferProgress")
$IconTransferProgress   = $Window.FindName("IconTransferProgress")
$TxtTransferAction      = $Window.FindName("TxtTransferAction")
$ProgBarTransfer        = $Window.FindName("ProgBarTransfer")
$TxtTransferPercent     = $Window.FindName("TxtTransferPercent")
$TxtTransferStatus      = $Window.FindName("TxtTransferStatus")

# ==============================================================================
# LOGO & TELEMETRY INITIALIZATION
# ==============================================================================
$localLogoPath = $null
if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot "assets\logo.png"))) {
    $localLogoPath = Join-Path $PSScriptRoot "assets\logo.png"
} elseif (Test-Path "assets\logo.png") {
    $localLogoPath = (Resolve-Path "assets\logo.png").Path
} elseif ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot "assets\folder.png"))) {
    $localLogoPath = Join-Path $PSScriptRoot "assets\folder.png"
}

if ($localLogoPath) {
    try {
        $bi = [System.Windows.Media.Imaging.BitmapImage]::new()
        $bi.BeginInit()
        $bi.UriSource = [System.Uri]::new($localLogoPath, [System.UriKind]::Absolute)
        $bi.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bi.EndInit()
        $bi.Freeze()

        $localIcoPath = if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot "assets\app_logo.ico"))) {
            Join-Path $PSScriptRoot "assets\app_logo.ico"
        } elseif ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot "assets\logo.ico"))) {
            Join-Path $PSScriptRoot "assets\logo.ico"
        } elseif (Test-Path "assets\app_logo.ico") {
            (Resolve-Path "assets\app_logo.ico").Path
        } elseif (Test-Path "assets\logo.ico") {
            (Resolve-Path "assets\logo.ico").Path
        } else { $null }

        if ($localIcoPath) {
            try {
                $Window.Icon = [System.Windows.Media.Imaging.BitmapFrame]::Create([System.Uri]::new($localIcoPath, [System.UriKind]::Absolute))
            } catch {
                $Window.Icon = $bi
            }
        } else {
            $Window.Icon = $bi
        }

        # Bind AppUserModelID and send Win32 WM_SETICON (ICON_BIG & ICON_SMALL) so Taskbar explicitly renders custom logo
        $Window.add_SourceInitialized({
            try {
                $helper = New-Object System.Windows.Interop.WindowInteropHelper($Window)
                $hwnd = $helper.Handle
                if ($hwnd -ne [IntPtr]::Zero) {
                    [ZeroExplore.ShellNative]::SetWindowAppId($hwnd, "ZeroExplore.FileExplorer.App")
                    if ($localIcoPath -and (Test-Path $localIcoPath)) {
                        [ZeroExplore.ShellNative]::SetWindowIcons($hwnd, $localIcoPath)
                    }
                }
            } catch {}
        })

        if ($ImgHeaderLogo) {
            $ImgHeaderLogo.Source = $bi
            if ($TxtHeaderFallbackLogo) { $TxtHeaderFallbackLogo.Visibility = "Collapsed" }
        }
        if ($ImgAboutLogo) {
            $ImgAboutLogo.Source = $bi
            if ($TxtAboutFallbackLogo) { $TxtAboutFallbackLogo.Visibility = "Collapsed" }
        }
    } catch {}
}

# Authentic WinRAR Icon Loader for Context Menu Items
$Script:WinRarIconImage = $null
$localWinRarPath = $null
if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot "assets\winrar.png"))) {
    $localWinRarPath = Join-Path $PSScriptRoot "assets\winrar.png"
} elseif (Test-Path "assets\winrar.png") {
    $localWinRarPath = (Resolve-Path "assets\winrar.png").Path
}

try {
    if ($localWinRarPath) {
        $biWr = [System.Windows.Media.Imaging.BitmapImage]::new()
        $biWr.BeginInit()
        $biWr.UriSource = [System.Uri]::new($localWinRarPath, [System.UriKind]::Absolute)
        $biWr.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $biWr.EndInit()
        $biWr.Freeze()
        $Script:WinRarIconImage = $biWr
    }
} catch {}

if (-not $Script:WinRarIconImage) {
    try {
        $wrBase64 = "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAoASURBVFhHxZd5WFXVGsZ3IuM5cAZmZTjMMweOyCzzrAiCYGooMpjMoqJ5yyuSGUiYmkYagpGpyaCi4RRDBFlB5pjRRb2S4C1ARCq6ar7321vQA2r/3vU8v2d9a5213vfbe6299j7M/71ga3UZNh9C/5sf/S2/5Fegr8UPQ5eTMHQpgViAe5cTcKcjBgPtszDwzSz0fxWO26c88G3OZtxaX4a+gr3P1WJhPVlvBoVVbX9k7URvSjFGrody9KZsHqX4SdydVAjczwH6g/B7txc6T0px8ZQMHfVO+Om4DHfPuwM3vIHbCTgVvRxdiW+hJ6VoVONZRrLfB3m3Mig51TuQ/h5uJVHnNS8ONn4KXQ3x78RCdFe54atkPdRmGKCrKQiD3clEEn78fAbqc41wNEqMG+9I8VlUNjoXbcTP3Fx5rad6rCd59zBIKxnuDE7DFf8UDH1txsHGY1z2TyVScMEvCb1bHFGfaYQHf+YCd5cCXdFEFNAzFw//uwiHM6bgaq45Dk6LRrvPYlz0S+bmPo8fg5cBacXDDIKWoNnMF80mM9B3RMDRQvEYzSY+3G8NEm+cn6+PoZ8XAFcjMXLOHyMdvhhscsNwg4z6AnHv53B8H6uPD/SdcELiiUZu/gsgT9ab6fOYPVynJ8UxPUfcruDhdjmPiydyVN8BHbM1gc443G3xxECjKwbOuOFWtRS3Dtij75AjcD4I7bM1UCiWoErPlpt3fILOU6ToJ2/mnMyvd5+mKT4WmeBmkQoHG1dOoEIkwaPTZHLMHqiyfVzXUP2p9WOOsbElHjXYI4+nje0ahtj7HJ0xPibPdvJmqpy92rYJpqKEr4tLy5U4Svg6cuhyFBN/FZuhf40BR+9KYvlUXMvQx63sKRhcZYC7q6bir43GSFQWYC1PjI08LbwjpyHPdvIk71bmsEdA2TZtY+Tz9fDlUkUONp7IP4maGE00b3JETZ4h6tYYoZo2HUtdugH2vaKL1hwL1IQKEU0JpKlpYTVPhxLReY4eJUGeh8ibORMQnlyqK8EqVdHfsoLoWmeK347MwLUdlrix3QKXKIlLa41xYbURrm2QoK/IEZ05BvBVVMV8ZXUsUxEgU0WIXFXhM3q7yLORvBkPz7yy6dNTIXWa/wRHOZ70SV/GT0WWuFvthu7dlri2xRYduRL8kG2CjmwJutYbo2+zFDcKzKGrZw8T2uW2drNh7zgXDtJ5NJ/VW0Baj5numgoPr9VlTEpqQ9uyjFNIWXoE185YcLBxqhxLkmuxYOEn6CqxQP8+F7p6M1wvlcJUNBmmwsm4WWCHcysM8VuRFF0FZmQcC//AdZgbX4GExZ8icUk1p5GcehgpBFsvyzhNdUMr82rG5d7kpQ1YknIaQ2dNONhYnpcXHseqzE3IWrYOfbtkuFFCB9Z+dxxZTqdflhF+oSv/PtsAN1daIT01D7npm+DrX4jY+Bq8sugzLE48hcTk00hKOYOk1MekLG3EqxkXe5hFyVeHY+PraHAdBpv1OWLjqD0G9YfPPIjK/U34oOw4HtZ74T9Hpfiz0Qv4biZwNgR/HJShp9QGj8qdUFpai737muDqsZHm7cOsqCpExdQiJu4opyUP683Ez7+CsIhDCJtZjTtnxBzhs6rH4RdQiW9/6MaXF37CrRUWOJeqj5PzdFAVIUZVqBgnIrXQFKONK/MMaUwXvuvsgVS2Ab4BexEYsh/BYZ+SfpWcZg21DyF+4RUw0XPODQcG70dQyAEMnBATIi6Wx2tGGX4dfoCbv95D42x91PqJsHW6AFfav8aJo8dRINXATlcNfOKjhRs0ZmgEsLVfDU/v92kpymk/VCIw+BMEkQ/nRQQE7UP0nI5hJjCkvneG7x54E32H6V1AsG15prttw1g5GKOP9wJEWOuthf7Be2j7vhOJ00TId9fAGuobK5ZWGXCSbYKr+3Z4eO+Cl89uzkMef/JmXN3L21xcd8DF9V1c/4iP65V8uLht5docFDtIC0ZlgQ8jdPF+sAivB+o+SSDFTYzlMnWslkvA2GQePQ2r6dFbD+dpRaRVQhey9SnuO+DuWd7KyFzeKXOZXgIn53yc3crnYGN5bO3o9TtaTiZ5osxHiLVuQgwN/47L/+pGrBUfaQ487IxzGR0FTJkaTnchFTa2ObCzf42e/XXjNFlPmcuWMsbRcX3ytGlbyCTvhVhapmGQrpYtj4iRgds4XXsA9x885JKo//hDPOzrwf3f7tKvD3HnziB0dH1hYroA5hapsLbOhLVt7jhN1pP1ZsQexmVidyOIphm8EKHTFLzxWi7uffc1Hpxvx/2L36JxTynyM5ciPyMFzR/twgPqe3ChHUPftNCZkQ4VQyE0rLUhsNeFwHEKRM7jNVlP1ptxfjuqzevgEnhUJKD7C3sOj/JFXHsM9z2vwO71MKTTbQ81VkaooTICDZQRMEowtSMlyggnsj2EnLhppifsN4bB+d1ouJTGw233wnGarCd5tzLSXXN6ZRXxkJXH49cvrThke6g9AefdcWhOlaAsUEgIsM1THds9NbCD2OaljlJfDeyi/rNZEmiFmEGS4QarNwNhVxIBhx1RcCqdC1kZaY1BfuTdw5jvDBw2L/KFWbEfHUL6HGw8EVMa81WGOWpninEoXITKYErERwMVvgKU+9EZECRETbgQl/LMIfCdCp2XrTA1WwajtW4wKfCCySYfmG1+qsd6st6MfpELdF6XQucNKfqO0jlAcG156DedfzjiyhpLNERp4vM5RLQmGimuo/f/EaIhUoSTEUJcXWMONTctqEcaQrDADFrLrKC1whY6axwe64xBuqw3o7/BaVh7pT20V9F3XTUlQLDxRLRybXFxpSVORopxbKaIjl8xnYqaaKFk6kJF+GKWCC2UxNU8S6i6aEI9zACCOAnEi8ygmW4D7Rzb8ZrkyXoz2lk2vZrp1tDMsMEvB9Q52Alsexxp1riQZY6TtAR1tAT1YWKcobiGlqKJ3gn1IULqoztAn+Uq9iLwfPWhMcsIwngTCBdbQjPV6rHOmDZ5st6MRqykTTDPBIJY+kJ5W42DjZ8hxhgdaRLU0FofJrPjlERtiAjHIqimjVk5Qx1H/AW4TJtQUcKHqpMYfG8d8AMpkXBaDpo/Ti/OBBoxklaG56dbph44BTwaPA6vZ9stoToosFZFoY0aiq3V8BbFtVIeCql+10oVGyxU0BSiA0VjHlRtBVBzEUPNVRs8d4LVk4PzJG/uD+pkqZLiJAMFp0naClGT9BSCJ+krBEzkJYPJvkFGvD/ybdURY87DbDNVhEpUkWBFsbkqIqidQHW8EW/kJcPJPs/TIAIn6ShEkoePgp0SnzNni3I2X0E5k89TyeErEgoTUSbYcUbz1HjeZko2rhZK9q5WSrbjsFSy8zZWdLAOVRWzY5WWP6szymTyUlPO4iszDMP8D0ljK6FLHvXEAAAAAElFTkSuQmCC"
        $wrBytes = [System.Convert]::FromBase64String($wrBase64)
        $wrMs = New-Object System.IO.MemoryStream($wrBytes, 0, $wrBytes.Length)
        $biWr = New-Object System.Windows.Media.Imaging.BitmapImage
        $biWr.BeginInit()
        $biWr.StreamSource = $wrMs
        $biWr.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $biWr.EndInit()
        $biWr.Freeze()
        $Script:WinRarIconImage = $biWr
    } catch {}
}

if ($Script:WinRarIconImage) {
    if ($ImgWinRar1) { $ImgWinRar1.Source = $Script:WinRarIconImage }
    if ($ImgWinRar2) { $ImgWinRar2.Source = $Script:WinRarIconImage }
    if ($ImgWinRar3) { $ImgWinRar3.Source = $Script:WinRarIconImage }
}

# Populate System Specs on About Page
try {
    if ($TxtAboutMachine) { $TxtAboutMachine.Text = $env:COMPUTERNAME }
    if ($TxtAboutOS) {
        $osObj = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        $caption = if ($osObj) { $osObj.Caption -replace "Microsoft\s+", "" } else { "Windows 10 Pro" }
        $arch = if ($osObj.OSArchitecture) { " ($($osObj.OSArchitecture))" } else { "" }
        $TxtAboutOS.Text = "$caption$arch"

        $displayVer = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name DisplayVersion -ErrorAction SilentlyContinue).DisplayVersion
        if (-not $displayVer) {
            $displayVer = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name ReleaseId -ErrorAction SilentlyContinue).ReleaseId
        }
        $ubr = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name UBR -ErrorAction SilentlyContinue).UBR
        $buildStr = if ($ubr) { "$($osObj.BuildNumber).$ubr" } else { "$($osObj.BuildNumber)" }
        $verPrefix = if ($displayVer) { "Version $displayVer • " } else { "" }
        if ($TxtAboutOSVersion) {
            $TxtAboutOSVersion.Text = "${verPrefix}Build $buildStr"
        }
    }
    if ($TxtAboutPS) { $TxtAboutPS.Text = "PS $($PSVersionTable.PSVersion) (STA)" }
    if ($TxtAboutRAM) {
        $csObj = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
        if ($csObj) {
            $ramGB = [Math]::Round($csObj.TotalPhysicalMemory / 1GB, 1)
            $TxtAboutRAM.Text = "$ramGB GB Total RAM"
        }
    }
} catch {}

# ==============================================================================
# VIEW SWITCHING (Explorer Files vs About Page)
# ==============================================================================
function Show-ExplorerFilesView {
    if ($ViewExplorerFiles) { $ViewExplorerFiles.Visibility = "Visible" }
    if ($ViewAbout) { $ViewAbout.Visibility = "Collapsed" }
    if ($Border_Nav_About) {
        $Border_Nav_About.Background = [System.Windows.Media.Brushes]::Transparent
        $Border_Nav_About.BorderThickness = [System.Windows.Thickness]::new(0)
    }
}

function Show-AboutView {
    if ($ViewExplorerFiles) { $ViewExplorerFiles.Visibility = "Collapsed" }
    if ($ViewAbout) { $ViewAbout.Visibility = "Visible" }
    Set-ActiveSidebarItem "Nav_About"
}

if ($Nav_About)              { $Nav_About.add_Click({ Show-AboutView }) }

# Website & Community Handlers
$OpenDonate = { Open-SafeBrowserUrl "https://zeroiq.site/" }

if ($BtnAboutWebsite)   { $BtnAboutWebsite.add_Click({ Open-SafeBrowserUrl "https://zeroiq.site/" }) }
if ($BtnSidebarWebsite) { $BtnSidebarWebsite.add_Click({ Open-SafeBrowserUrl "https://zeroiq.site/" }) }
if ($BtnSidebarDonate)  { $BtnSidebarDonate.add_Click({ Open-SafeBrowserUrl "https://zeroiq.site/" }) }
if ($BtnAboutGithub)    { $BtnAboutGithub.add_Click({ Open-SafeBrowserUrl "https://github.com/ZeroIQs" }) }
if ($BtnAboutDonate)    { $BtnAboutDonate.add_Click($OpenDonate) }
if ($BtnProjectZeroHub)    { $BtnProjectZeroHub.add_Click({ Open-SafeBrowserUrl "https://github.com/ZeroIQs/Zerohub" }) }
if ($BtnProjectExPDF)      { $BtnProjectExPDF.add_Click({ Open-SafeBrowserUrl "https://expdf.space/" }) }
if ($BtnProjectWallpapers) { $BtnProjectWallpapers.add_Click({ Open-SafeBrowserUrl "https://zeroiqs.github.io/ZeroIQ-Wallpapers/" }) }
function Set-SidebarUpdateButtonVisuals([string]$mode, [string]$tag = "") {
    if (-not $BorderSidebarUpdate -or -not $TxtSidebarUpdate) { return }

    $brushConv = [System.Windows.Media.BrushConverter]::new()

    if ($mode -eq "UPDATE_AVAILABLE") {
        # Vibrant Crimson Red Styling for Available Update
        $BorderSidebarUpdate.Background  = $brushConv.ConvertFromString("#E11D48")
        $BorderSidebarUpdate.BorderBrush = $brushConv.ConvertFromString("#FB7185")
        if ($IconSidebarUpdate) {
            $IconSidebarUpdate.Text       = [char]0xE896 # Download glyph
            $IconSidebarUpdate.Foreground = [System.Windows.Media.Brushes]::White
        }
        $TxtSidebarUpdate.Text       = "Update $tag Available!"
        $TxtSidebarUpdate.Foreground = [System.Windows.Media.Brushes]::White
        if ($BadgeSidebarUpdateArrow) {
            $BadgeSidebarUpdateArrow.Foreground = [System.Windows.Media.Brushes]::White
        }
    }
    elseif ($mode -eq "UP_TO_DATE") {
        # Green Checkmark state: User has the latest version
        $BorderSidebarUpdate.Background  = $brushConv.ConvertFromString("#064E3B")
        $BorderSidebarUpdate.BorderBrush = $brushConv.ConvertFromString("#059669")
        if ($IconSidebarUpdate) {
            $IconSidebarUpdate.Text       = [char]0xE73E # Checkmark glyph
            $IconSidebarUpdate.Foreground = $brushConv.ConvertFromString("#4ADE80")
        }
        $TxtSidebarUpdate.Text       = "You are using the latest version"
        $TxtSidebarUpdate.Foreground = $brushConv.ConvertFromString("#4ADE80")
        if ($BadgeSidebarUpdateArrow) {
            $BadgeSidebarUpdateArrow.Foreground = $brushConv.ConvertFromString("#4ADE80")
        }
    }
    elseif ($mode -eq "CHECKING") {
        # Checking state
        $BorderSidebarUpdate.Background  = $brushConv.ConvertFromString("#111827")
        $BorderSidebarUpdate.BorderBrush = $brushConv.ConvertFromString("#0284C7")
        if ($IconSidebarUpdate) {
            $IconSidebarUpdate.Text       = [char]0xE72C # Sync glyph
            $IconSidebarUpdate.Foreground = $brushConv.ConvertFromString("#D4D4D8")
        }
        $TxtSidebarUpdate.Text       = "Checking..."
        $TxtSidebarUpdate.Foreground = $brushConv.ConvertFromString("#D4D4D8")
        if ($BadgeSidebarUpdateArrow) {
            $BadgeSidebarUpdateArrow.Foreground = $brushConv.ConvertFromString("#D4D4D8")
        }
    }
    else {
        # Normal Idle State
        $BorderSidebarUpdate.Background  = $brushConv.ConvertFromString("#111114")
        $BorderSidebarUpdate.BorderBrush = $brushConv.ConvertFromString("#23232A")
        if ($IconSidebarUpdate) {
            $IconSidebarUpdate.Text       = [char]0xE72C # Sync glyph
            $IconSidebarUpdate.Foreground = $brushConv.ConvertFromString("#c15f3c")
        }
        $TxtSidebarUpdate.Text       = "Check for Updates"
        $TxtSidebarUpdate.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#F5EDE0")
        if ($BadgeSidebarUpdateArrow) {
            $BadgeSidebarUpdateArrow.Foreground = $brushConv.ConvertFromString("#A1A1AA")
        }
    }
}

$Script:IsManualUpdateCheck = $false

function Check-GitHubAppUpdateAsync([bool]$isManual = $false) {
    $Script:IsManualUpdateCheck = $isManual

    if ($isManual) {
        if ($BtnManualCheckUpdates) {
            $BtnManualCheckUpdates.IsEnabled = $false
            $BtnManualCheckUpdates.Content = "[...] Checking for Updates..."
        }
        if ($TxtAppUpdateStatus) {
            $TxtAppUpdateStatus.Text = "Checking for new releases on GitHub..."
            $TxtAppUpdateStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#D4D4D8")
        }
        Set-SidebarUpdateButtonVisuals "CHECKING"
    }

    # Instant offline check: If no network adapter is online, skip in 0ms!
    $isOnline = $false
    try {
        $isOnline = [System.Net.NetworkInformation.NetworkInterface]::GetIsNetworkAvailable()
    } catch {}

    if (-not $isOnline) {
        if ($Script:IsManualUpdateCheck) {
            if ($TxtAppUpdateStatus) {
                $TxtAppUpdateStatus.Text = "Offline Mode (No Internet Connection)"
                $TxtAppUpdateStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#94A3B8")
            }
            Set-SidebarUpdateButtonVisuals "NORMAL"
            if ($BtnManualCheckUpdates) {
                $BtnManualCheckUpdates.IsEnabled = $true
                $BtnManualCheckUpdates.Content = "[Refresh] Check for Updates"
            }
        }
        return
    }

    try {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls

        $ts = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        $rawUrl = "https://raw.githubusercontent.com/$($Script:GitHubRepo)/main/ZeroExplore.ps1?nocache=$ts"

        $Script:UpdateWebClient = New-Object System.Net.WebClient
        $Script:UpdateWebClient.Headers.Add("User-Agent", "ZeroExplorer-UpdateChecker")
        $Script:UpdateWebClient.Headers.Add("Cache-Control", "no-cache, no-store, must-revalidate")

        $Script:UpdateWebClient.add_DownloadStringCompleted({
            param($srcClient, $e)
            if (-not $Window) { return }

            $Window.Dispatcher.Invoke([Action]{
                $wasManual = $Script:IsManualUpdateCheck
                try {
                    $hasErr = $e.Error -or [string]::IsNullOrWhiteSpace($e.Result)
                    if ($hasErr) {
                        if ($TxtAppUpdateStatus) {
                            $TxtAppUpdateStatus.Text = "You are using the latest version (v$($Script:CurrentAppVersion))"
                            $TxtAppUpdateStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#4ADE80")
                        }
                        if ($wasManual) {
                            Set-SidebarUpdateButtonVisuals "UP_TO_DATE"
                            if ($BtnManualCheckUpdates) {
                                $BtnManualCheckUpdates.Content = "[OK] You are using the latest version"
                            }

                            if ($Script:UpdateResetTimer) { $Script:UpdateResetTimer.Stop() }
                            $Script:UpdateResetTimer = New-Object System.Windows.Threading.DispatcherTimer
                            $Script:UpdateResetTimer.Interval = [TimeSpan]::FromSeconds(3.5)
                            $Script:UpdateResetTimer.Add_Tick({
                                $Script:UpdateResetTimer.Stop()
                                if (-not $Script:HasAvailableUpdate) {
                                    Set-SidebarUpdateButtonVisuals "NORMAL"
                                    if ($BtnManualCheckUpdates) {
                                        $BtnManualCheckUpdates.Content = "[Refresh] Check for Updates"
                                    }
                                }
                            })
                            $Script:UpdateResetTimer.Start()
                        } else {
                            Set-SidebarUpdateButtonVisuals "NORMAL"
                            if ($BtnManualCheckUpdates) {
                                $BtnManualCheckUpdates.Content = "[Refresh] Check for Updates"
                            }
                        }
                        return
                    }

                    $rawText = $e.Result
                    $cleanTag = $null
                    if ($rawText -match '\$Script:CurrentAppVersion\s*=\s*["'']([^"'']+)["'']') {
                        $cleanTag = $Matches[1].Trim().TrimStart('v', 'V')
                    }

                    if (-not [string]::IsNullOrWhiteSpace($cleanTag)) {
                        $curVer = [System.Version]::Parse($Script:CurrentAppVersion)
                        $latVer = [System.Version]::Parse($cleanTag)

                        if ($latVer -gt $curVer) {
                            # Newer release found on GitHub -> Highlight RED button!
                            $Script:HasAvailableUpdate = $true
                            $Script:LatestUpdateTag   = $cleanTag

                            Set-SidebarUpdateButtonVisuals "UPDATE_AVAILABLE" "v$cleanTag"

                            if ($TxtAppUpdateStatus) {
                                $TxtAppUpdateStatus.Text = "New version available on GitHub: v$cleanTag"
                                $TxtAppUpdateStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FB7185")
                            }
                            if ($BtnAppUpdateTab) {
                                $BtnAppUpdateTab.Visibility = [System.Windows.Visibility]::Visible
                                $BtnAppUpdateTab.Content = "[>>] Install v$cleanTag"
                            }
                            if ($BtnManualCheckUpdates) {
                                $BtnManualCheckUpdates.Content = "[Refresh] Re-check GitHub"
                            }
                        } else {
                            # Up to date
                            $Script:HasAvailableUpdate = $false
                            if ($TxtAppUpdateStatus) {
                                $TxtAppUpdateStatus.Text = "You are using the latest version (v$($Script:CurrentAppVersion))"
                                $TxtAppUpdateStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#4ADE80")
                            }
                            if ($BtnAppUpdateTab) {
                                $BtnAppUpdateTab.Visibility = [System.Windows.Visibility]::Collapsed
                            }

                            if ($wasManual) {
                                Set-SidebarUpdateButtonVisuals "UP_TO_DATE"
                                if ($BtnManualCheckUpdates) {
                                    $BtnManualCheckUpdates.Content = "[OK] You are using the latest version"
                                }

                                if ($Script:UpdateResetTimer) { $Script:UpdateResetTimer.Stop() }
                                $Script:UpdateResetTimer = New-Object System.Windows.Threading.DispatcherTimer
                                $Script:UpdateResetTimer.Interval = [TimeSpan]::FromSeconds(3.5)
                                $Script:UpdateResetTimer.Add_Tick({
                                    $Script:UpdateResetTimer.Stop()
                                    if (-not $Script:HasAvailableUpdate) {
                                        Set-SidebarUpdateButtonVisuals "NORMAL"
                                        if ($BtnManualCheckUpdates) {
                                            $BtnManualCheckUpdates.Content = "[Refresh] Check for Updates"
                                        }
                                    }
                                })
                                $Script:UpdateResetTimer.Start()
                            } else {
                                Set-SidebarUpdateButtonVisuals "NORMAL"
                                if ($BtnManualCheckUpdates) {
                                    $BtnManualCheckUpdates.Content = "[Refresh] Check for Updates"
                                }
                            }
                        }
                    } else {
                        if ($wasManual) {
                            Set-SidebarUpdateButtonVisuals "UP_TO_DATE"
                            if ($BtnManualCheckUpdates) {
                                $BtnManualCheckUpdates.Content = "[OK] You are using the latest version"
                            }
                            if ($Script:UpdateResetTimer) { $Script:UpdateResetTimer.Stop() }
                            $Script:UpdateResetTimer = New-Object System.Windows.Threading.DispatcherTimer
                            $Script:UpdateResetTimer.Interval = [TimeSpan]::FromSeconds(3.5)
                            $Script:UpdateResetTimer.Add_Tick({
                                $Script:UpdateResetTimer.Stop()
                                if (-not $Script:HasAvailableUpdate) {
                                    Set-SidebarUpdateButtonVisuals "NORMAL"
                                    if ($BtnManualCheckUpdates) {
                                        $BtnManualCheckUpdates.Content = "[Refresh] Check for Updates"
                                    }
                                }
                            })
                            $Script:UpdateResetTimer.Start()
                        } else {
                            Set-SidebarUpdateButtonVisuals "NORMAL"
                            if ($BtnManualCheckUpdates) {
                                $BtnManualCheckUpdates.Content = "[Refresh] Check for Updates"
                            }
                        }
                    }
                } finally {
                    if ($BtnManualCheckUpdates) {
                        $BtnManualCheckUpdates.IsEnabled = $true
                    }
                    try { $srcClient.Dispose() } catch {}
                }
            })
        })

        $Script:UpdateWebClient.DownloadStringAsync([Uri]::new($rawUrl))
    } catch {
        if ($Script:IsManualUpdateCheck) {
            Set-SidebarUpdateButtonVisuals "NORMAL"
            if ($BtnManualCheckUpdates) {
                $BtnManualCheckUpdates.IsEnabled = $true
                $BtnManualCheckUpdates.Content = "[Refresh] Check for Updates"
            }
        }
    }
}

function Invoke-PerformSelfAppUpdate {
    if (-not $Script:HasAvailableUpdate) {
        Check-GitHubAppUpdateAsync $true
        return
    }

    $confirmMsg = "Download and install ZeroExplorer ($($Script:LatestUpdateTag)) from GitHub now? The application will update in-place wherever it is stored and automatically restart."
    $res = [System.Windows.MessageBox]::Show($confirmMsg, "ZeroExplorer Auto-Updater", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
    if ($res -eq [System.Windows.MessageBoxResult]::Yes) {
        try {
            # 1. Retrieve the exact running script path stored at startup
            $targetPs1 = $Script:RunningScriptPath
            if (-not $targetPs1 -or -not (Test-Path $targetPs1)) {
                if ($PSCommandPath -and (Test-Path $PSCommandPath)) {
                    $targetPs1 = $PSCommandPath
                } elseif ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot "ZeroExplore.ps1"))) {
                    $targetPs1 = Join-Path $PSScriptRoot "ZeroExplore.ps1"
                } elseif (Test-Path (Join-Path (Get-Location).Path "ZeroExplore.ps1")) {
                    $targetPs1 = Join-Path (Get-Location).Path "ZeroExplore.ps1"
                } else {
                    $targetPs1 = Join-Path $env:LOCALAPPDATA "ZeroExplorer\ZeroExplore.ps1"
                }
            }

            $targetDir = Split-Path -Path $targetPs1 -Parent

            # 2. Download newest release files to TEMP
            $ts = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
            $tempPs1 = Join-Path $env:TEMP "ZeroExplorer_Update_$ts.ps1"

            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls
            $wc = New-Object System.Net.WebClient
            $wc.Headers.Add("User-Agent", "ZeroExplorer-AutoUpdater")
            $wc.DownloadFile("https://raw.githubusercontent.com/$($Script:GitHubRepo)/main/ZeroExplore.ps1?nocache=$ts", $tempPs1)

            # 3. Integrity Verification (> 100 KB)
            if ((Test-Path $tempPs1) -and ((Get-Item $tempPs1).Length -gt 100000)) {
                # In-place overwrite in user's current folder
                Copy-Item -Path $tempPs1 -Destination $targetPs1 -Force

                # Also synchronize %LOCALAPPDATA%\ZeroExplorer cache if it exists
                $appDataDir = Join-Path $env:LOCALAPPDATA "ZeroExplorer"
                if (Test-Path $appDataDir) {
                    try {
                        Copy-Item -Path $tempPs1 -Destination (Join-Path $appDataDir "ZeroExplore.ps1") -Force
                    } catch {}
                }

                # Clean temporary downloaded files
                try { Remove-Item $tempPs1 -Force -ErrorAction SilentlyContinue } catch {}

                # 4. Seamlessly relaunch the updated ZeroExplorer instance
                $launchArgs = "-NoProfile -ExecutionPolicy Bypass -STA -File `"$targetPs1`""
                Start-Process "powershell.exe" -ArgumentList $launchArgs -WorkingDirectory $targetDir
                $Window.Close()
            } else {
                throw "Downloaded update file was incomplete. Please check your internet connection."
            }
        } catch {
            [System.Windows.MessageBox]::Show("Update failed: $($_.Exception.Message)", "ZeroExplorer Update Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        }
    }
}

if ($BtnManualCheckUpdates) {
    $BtnManualCheckUpdates.add_Click({ Check-GitHubAppUpdateAsync $true })
}
if ($BtnAppUpdateTab) {
    $BtnAppUpdateTab.add_Click({ Invoke-PerformSelfAppUpdate })
}
if ($BtnSidebarUpdate) {
    $BtnSidebarUpdate.add_Click({
        Show-AboutView
        if ($Script:HasAvailableUpdate) {
            Invoke-PerformSelfAppUpdate
        } else {
            Check-GitHubAppUpdateAsync $true
        }
    })
}

# ==============================================================================
# QUICK PIN ACTIONS & WINDOW CONTROLS
# ==============================================================================
if ($BtnAddToDesktop) {
    $BtnAddToDesktop.add_Click({
        try {
            $WshShell = New-Object -ComObject WScript.Shell
            $desktop = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Desktop)
            $shortcutPath = Join-Path $desktop "ZeroExplorer.lnk"
            $workstationDir = if ($Script:AppDir) { $Script:AppDir } elseif ($PSScriptRoot) { $PSScriptRoot } elseif ($PSCommandPath) { Split-Path -Parent $PSCommandPath } else { (Get-Location).Path }
            $ps1Path = Join-Path $workstationDir "ZeroExplore.ps1"
            $icoPath = if (Test-Path (Join-Path $workstationDir "assets\app_logo.ico")) {
                Join-Path $workstationDir "assets\app_logo.ico"
            } elseif (Test-Path (Join-Path $workstationDir "assets\logo.ico")) {
                Join-Path $workstationDir "assets\logo.ico"
            } else {
                Join-Path $workstationDir "assets\folder.ico"
            }

            $vbsPath = Join-Path $workstationDir "ZeroExplore.vbs"
            $sc = $WshShell.CreateShortcut($shortcutPath)
            if (Test-Path $vbsPath) {
                $sc.TargetPath = "wscript.exe"
                $sc.Arguments = "`"$vbsPath`""
            } else {
                $sc.TargetPath = "powershell.exe"
                $sc.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -STA -File `"$ps1Path`""
            }
            $sc.WorkingDirectory = $workstationDir
            $sc.WindowStyle = 1
            if (Test-Path $icoPath) { $sc.IconLocation = "$icoPath,0" }
            $sc.Description = "ZeroExplorer - File Explorer"
            $sc.Save()

            try {
                [ZeroExplore.ShellNative]::SetShortcutAppId($shortcutPath, "ZeroExplore.FileExplorer.App")
                [ZeroExplore.ShellNative]::SHChangeNotify(0x08000000, 0x0000, [IntPtr]::Zero, [IntPtr]::Zero)
            } catch {}

            if ($TxtTransferStatus) { $TxtTransferStatus.Text = "ZeroExplorer shortcut added to Desktop!" }
            [System.Windows.MessageBox]::Show("ZeroExplorer shortcut was successfully added to your Desktop!", "Desktop Shortcut Created", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        } catch {
            [System.Windows.MessageBox]::Show("Failed to create Desktop shortcut: $($_.Exception.Message)", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        }
    })
}

$BtnWindowMin.add_Click({ $Window.WindowState = [System.Windows.WindowState]::Minimized })
$BtnWindowMax.add_Click({
    if ($Window.WindowState -eq [System.Windows.WindowState]::Maximized) {
        $Window.WindowState = [System.Windows.WindowState]::Normal
        $TxtMaxIcon.Text = [char]0xE922
    } else {
        $Window.WindowState = [System.Windows.WindowState]::Maximized
        $TxtMaxIcon.Text = [char]0xE923
    }
})
$BtnWindowClose.add_Click({ $Window.Close() })

# Media player ticker (Smooth 200ms interval)
$mediaTimer = New-Object System.Windows.Threading.DispatcherTimer
$mediaTimer.Interval = [System.TimeSpan]::FromMilliseconds(200)
$mediaTimer.Add_Tick({
    if ($PreviewMediaElement -and $PreviewMediaElement.NaturalDuration.HasTimeSpan) {
        if ($Script:IsUserDraggingSlider) { return }
        if ($Script:LastSeekTime -and ([System.DateTime]::UtcNow - $Script:LastSeekTime).TotalMilliseconds -lt 1500) {
            return
        }
        $cur = $PreviewMediaElement.Position
        $dur = $PreviewMediaElement.NaturalDuration.TimeSpan
        if ($dur.TotalSeconds -gt 0) {
            $SliderMediaTimeline.Maximum = $dur.TotalSeconds
            $SliderMediaTimeline.Value = $cur.TotalSeconds
            $curStr = "{0:mm\:ss}" -f $cur
            $durStr = "{0:mm\:ss}" -f $dur
            if ($TxtMediaTime) { $TxtMediaTime.Text = "$curStr / $durStr" }
        }
    }
})

# ==============================================================================
# DYNAMIC DRIVE BUTTONS & SIDEBAR HIGHLIGHTING (ZeroHub Unified Style)
# ==============================================================================
$Script:CurrentActiveSidebarId = "Drive_C"

# ==============================================================================
# QUICK ACCESS PINNED FOLDERS MANAGEMENT & PERSISTENCE
# ==============================================================================
$Script:PinnedFoldersConfigFile = Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::ApplicationData)) "ZeroExplore\pinned_folders.json"
$Script:PinnedFolders = [System.Collections.Generic.List[string]]::new()

function New-DarkContextMenu {
    $cm = New-Object System.Windows.Controls.ContextMenu
    $cm.Style = $Window.FindResource("DarkObsidianContextMenu")
    return $cm
}

function New-DarkMenuItem([string]$header, [string]$glyph, [string]$glyphColor, [scriptblock]$action) {
    $mi = New-Object System.Windows.Controls.MenuItem
    $mi.Style = $Window.FindResource("DarkObsidianMenuItem")
    $mi.Header = $header
    if ($glyph) {
        $tb = New-Object System.Windows.Controls.TextBlock
        $tb.Text = $glyph
        $tb.FontFamily = New-Object System.Windows.Media.FontFamily("Segoe MDL2 Assets")
        $tb.FontSize = 11
        if ($glyphColor) {
            $tb.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($glyphColor)
        }
        $mi.Icon = $tb
    }
    if ($action) {
        $mi.Add_Click($action)
    }
    return $mi
}

function Load-PinnedFolders {
    $Script:PinnedFolders.Clear()
    try {
        if (Test-Path -LiteralPath $Script:PinnedFoldersConfigFile) {
            $json = Get-Content -LiteralPath $Script:PinnedFoldersConfigFile -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
            if ($json) {
                $rawArr = $json | ConvertFrom-Json
                $arr = @($rawArr)
                foreach ($p in $arr) {
                    if ($p -and (Test-Path -LiteralPath $p)) {
                        $norm = [System.IO.Path]::GetFullPath($p).TrimEnd('\')
                        $already = $false
                        foreach ($existing in $Script:PinnedFolders) {
                            if ([string]::Equals($existing, $norm, [System.StringComparison]::OrdinalIgnoreCase)) {
                                $already = $true
                                break
                            }
                        }
                        if (-not $already) {
                            $Script:PinnedFolders.Add($norm)
                        }
                    }
                }
            }
        }
    } catch {}
}

function Save-PinnedFolders {
    try {
        $parentDir = [System.IO.Path]::GetDirectoryName($Script:PinnedFoldersConfigFile)
        if (-not (Test-Path -LiteralPath $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }
        $arr = @($Script:PinnedFolders)
        $json = ConvertTo-Json -InputObject $arr -Compress:$false
        Set-Content -LiteralPath $Script:PinnedFoldersConfigFile -Value $json -Encoding UTF8 -Force
    } catch {}
}

function Update-QuickAccessPinnedButtons {
    if (-not $PanelQuickAccessCustom) { return }
    $PanelQuickAccessCustom.Children.Clear()

    foreach ($path in $Script:PinnedFolders) {
        if (-not $path -or -not (Test-Path -LiteralPath $path)) { continue }

        $folderName = [System.IO.Path]::GetFileName($path)
        if ([string]::IsNullOrWhiteSpace($folderName)) { $folderName = $path }

        # Outer Row Border (No nested buttons - clean layout and event handling)
        $itemBorder = New-Object System.Windows.Controls.Border
        $itemBorder.CornerRadius = [System.Windows.CornerRadius]::new(6)
        $itemBorder.Margin = [System.Windows.Thickness]::new(0, 1.5, 0, 1.5)
        $itemBorder.Padding = [System.Windows.Thickness]::new(10, 6, 6, 6)
        $itemBorder.Background = [System.Windows.Media.Brushes]::Transparent
        $itemBorder.BorderThickness = [System.Windows.Thickness]::new(0)
        $itemBorder.Cursor = [System.Windows.Input.Cursors]::Hand
        $itemBorder.Tag = $path
        $itemBorder.ToolTip = "Pinned: $path"

        $grid = New-Object System.Windows.Controls.Grid
        $grid.VerticalAlignment = [System.Windows.VerticalAlignment]::Center

        $col0 = New-Object System.Windows.Controls.ColumnDefinition
        $col0.Width = [System.Windows.GridLength]::new(22)
        $col1 = New-Object System.Windows.Controls.ColumnDefinition
        $col1.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
        $col2 = New-Object System.Windows.Controls.ColumnDefinition
        $col2.Width = [System.Windows.GridLength]::new(24)

        $grid.ColumnDefinitions.Add($col0)
        $grid.ColumnDefinitions.Add($col1)
        $grid.ColumnDefinitions.Add($col2)

        # Folder Glyph (MDL2 0xED25 in Soft Purple #A78BFA)
        $tbIcon = New-Object System.Windows.Controls.TextBlock
        $tbIcon.Text = [char]0xED25
        $tbIcon.FontFamily = New-Object System.Windows.Media.FontFamily("Segoe MDL2 Assets")
        $tbIcon.FontSize = 12.5
        $tbIcon.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#A78BFA")
        $tbIcon.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
        $tbIcon.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        $tbIcon.Tag = "Icon"
        [System.Windows.Controls.Grid]::SetColumn($tbIcon, 0)
        $grid.Children.Add($tbIcon) | Out-Null

        # Folder Name Text
        $tbLabel = New-Object System.Windows.Controls.TextBlock
        $tbLabel.Text = $folderName
        $tbLabel.FontSize = 11.5
        $tbLabel.FontWeight = [System.Windows.FontWeights]::SemiBold
        $tbLabel.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#F5EDE0")
        $tbLabel.Margin = [System.Windows.Thickness]::new(6, 0, 4, 0)
        $tbLabel.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        $tbLabel.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis
        $tbLabel.Tag = "Label"
        [System.Windows.Controls.Grid]::SetColumn($tbLabel, 1)
        $grid.Children.Add($tbLabel) | Out-Null

        # Unpin Button Container (Independent sibling element - cannot trigger row navigation)
        $borderUnpin = New-Object System.Windows.Controls.Border
        $borderUnpin.Width = 20
        $borderUnpin.Height = 20
        $borderUnpin.CornerRadius = [System.Windows.CornerRadius]::new(4)
        $borderUnpin.Background = [System.Windows.Media.Brushes]::Transparent
        $borderUnpin.Cursor = [System.Windows.Input.Cursors]::Hand
        $borderUnpin.ToolTip = "Unpin '$folderName' from Quick Access"
        $borderUnpin.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        $borderUnpin.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Right

        $tbUnpin = New-Object System.Windows.Controls.TextBlock
        $tbUnpin.Text = [char]0xE77A  # Unpin glyph
        $tbUnpin.FontFamily = New-Object System.Windows.Media.FontFamily("Segoe MDL2 Assets")
        $tbUnpin.FontSize = 10
        $tbUnpin.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#71717A")
        $tbUnpin.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
        $tbUnpin.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        $borderUnpin.Child = $tbUnpin

        # Bind closure variables cleanly
        $pinnedTarget = $path
        $borderUnpin.Add_MouseLeftButtonUp({
            param($s, $e)
            if ($e) { $e.Handled = $true }
            Unpin-ExplorerQuickAccessPath $pinnedTarget
        }.GetNewClosure())

        $borderUnpin.Add_MouseEnter({
            $borderUnpin.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#2E1E19")
            $tbUnpin.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#c15f3c")
        })
        $borderUnpin.Add_MouseLeave({
            $borderUnpin.Background = [System.Windows.Media.Brushes]::Transparent
            $tbUnpin.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#71717A")
        })

        [System.Windows.Controls.Grid]::SetColumn($borderUnpin, 2)
        $grid.Children.Add($borderUnpin) | Out-Null

        $itemBorder.Child = $grid

        # Row Click -> Navigate to Folder
        $itemBorder.Add_MouseLeftButtonUp({
            param($s, $e)
            if (-not $e.Handled) {
                Show-ExplorerFilesView
                Navigate-ExplorerFolder $pinnedTarget
            }
        }.GetNewClosure())

        # Row Hover
        $itemBorder.Add_MouseEnter({
            $cId = "Pinned_" + $pinnedTarget.TrimEnd('\')
            if ($Script:CurrentActiveSidebarId -ne $cId) {
                $itemBorder.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#18181C")
            }
        }.GetNewClosure())

        $itemBorder.Add_MouseLeave({
            $cId = "Pinned_" + $pinnedTarget.TrimEnd('\')
            if ($Script:CurrentActiveSidebarId -ne $cId) {
                $itemBorder.Background = [System.Windows.Media.Brushes]::Transparent
            } else {
                $itemBorder.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#23232A")
            }
        }.GetNewClosure())

        # Styled Dark Obsidian Right-Click Context Menu
        $cm = New-DarkContextMenu

        $miOpen = New-DarkMenuItem "Open" ([char]0xED25) "#38BDF8" {
            Show-ExplorerFilesView
            Navigate-ExplorerFolder $pinnedTarget
        }.GetNewClosure()
        $cm.Items.Add($miOpen) | Out-Null

        $miExplorer = New-DarkMenuItem "Open in Windows Explorer" ([char]0xE8A7) "#F59E0B" {
            Start-Process "explorer.exe" -ArgumentList "`"$pinnedTarget`""
        }.GetNewClosure()
        $cm.Items.Add($miExplorer) | Out-Null

        $sep = New-Object System.Windows.Controls.Separator
        $sep.Style = $Window.FindResource("DarkObsidianSeparator")
        $cm.Items.Add($sep) | Out-Null

        $miUnpin = New-DarkMenuItem "Unpin from Quick Access" ([char]0xE77A) "#c15f3c" {
            Unpin-ExplorerQuickAccessPath $pinnedTarget
        }.GetNewClosure()
        $cm.Items.Add($miUnpin) | Out-Null

        $itemBorder.ContextMenu = $cm
        $PanelQuickAccessCustom.Children.Add($itemBorder) | Out-Null
    }

    # Re-apply active highlight if current directory is pinned
    if ($Script:ExplorerCurrentPath) {
        Update-SidebarSelectionForPath $Script:ExplorerCurrentPath
    }
}

function Pin-ExplorerQuickAccessPath([string]$path) {
    if (-not $path -or -not (Test-Path -LiteralPath $path)) { return }
    if (-not (Test-Path -LiteralPath $path -PathType Container)) {
        $path = [System.IO.Path]::GetDirectoryName($path)
    }
    if (-not $path -or -not (Test-Path -LiteralPath $path)) { return }

    $normPath = [System.IO.Path]::GetFullPath($path).TrimEnd('\')
    if (-not $Script:PinnedFolders) {
        $Script:PinnedFolders = [System.Collections.Generic.List[string]]::new()
    }

    $already = $false
    foreach ($existing in $Script:PinnedFolders) {
        if ([string]::Equals($existing, $normPath, [System.StringComparison]::OrdinalIgnoreCase)) {
            $already = $true
            break
        }
    }

    if (-not $already) {
        $Script:PinnedFolders.Add($normPath)
        Save-PinnedFolders
        Update-QuickAccessPinnedButtons
        if ($TxtTransferStatus) {
            $TxtTransferStatus.Text = "Pinned '$([System.IO.Path]::GetFileName($normPath))' to Quick Access."
        }
    } else {
        if ($TxtTransferStatus) {
            $TxtTransferStatus.Text = "'$([System.IO.Path]::GetFileName($normPath))' is already pinned."
        }
    }
}

function Unpin-ExplorerQuickAccessPath([string]$path) {
    if (-not $path) { return }
    $normPath = [System.IO.Path]::GetFullPath($path).TrimEnd('\')
    
    $newPins = [System.Collections.Generic.List[string]]::new()
    $found = $false
    foreach ($p in $Script:PinnedFolders) {
        if ($p -and [string]::Equals([System.IO.Path]::GetFullPath($p).TrimEnd('\'), $normPath, [System.StringComparison]::OrdinalIgnoreCase)) {
            $found = $true
        } else {
            $newPins.Add($p)
        }
    }

    if ($found) {
        $Script:PinnedFolders = $newPins
        Save-PinnedFolders
        Update-QuickAccessPinnedButtons
        if ($TxtTransferStatus) {
            $TxtTransferStatus.Text = "Unpinned '$([System.IO.Path]::GetFileName($normPath))' from Quick Access."
        }
    }

    # Also invoke Windows Shell unpin in background
    try {
        $shell = New-Object -ComObject Shell.Application
        $folder = $shell.Namespace($normPath)
        if ($folder) {
            $folder.Self.InvokeVerb("unpinfromhome")
        }
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) | Out-Null
    } catch {}
}

function Set-ActiveSidebarItem([string]$activeId) {
    $Script:CurrentActiveSidebarId = $activeId

    # 1. Quick Access & Information items (ZeroHub Exact Style: #23232A activeBg, #FDFBF7 activeFg, BorderThickness=0 ALWAYS)
    $quickItems = @(
        @{ Id = "Quick_Desktop";   Border = $Border_Quick_Desktop;   Text = $Txt_Quick_Desktop;   Icon = $Icon_Quick_Desktop;   OrigColor = "#F59E0B" },
        @{ Id = "Quick_Downloads"; Border = $Border_Quick_Downloads; Text = $Txt_Quick_Downloads; Icon = $Icon_Quick_Downloads; OrigColor = "#38BDF8" },
        @{ Id = "Quick_Documents"; Border = $Border_Quick_Documents; Text = $Txt_Quick_Documents; Icon = $Icon_Quick_Documents; OrigColor = "#4ADE80" },
        @{ Id = "Quick_AppData";   Border = $Border_Quick_AppData;   Text = $Txt_Quick_AppData;   Icon = $Icon_Quick_AppData;   OrigColor = "#A1A1AA" },
        @{ Id = "Quick_Temp";      Border = $Border_Quick_Temp;      Text = $Txt_Quick_Temp;      Icon = $Icon_Quick_Temp;      OrigColor = "#FB923C" },
        @{ Id = "Quick_RecycleBin"; Border = $Border_Quick_RecycleBin; Text = $Txt_Quick_RecycleBin; Icon = $Icon_Quick_RecycleBin; OrigColor = "#F87171" },
        @{ Id = "Nav_About";       Border = $Border_Nav_About;       Text = $Txt_Nav_About;       Icon = $Icon_Nav_About;       OrigColor = "#38BDF8" }
    )

    $activeBg       = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#23232A")
    $activeFg       = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FDFBF7")
    $inactiveBg     = [System.Windows.Media.Brushes]::Transparent
    $inactiveFg     = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#94A3B8")

    foreach ($item in $quickItems) {
        if ($item.Border) {
            # Keep BorderThickness constant at 0 at all times so items NEVER shift/move!
            $item.Border.BorderThickness = [System.Windows.Thickness]::new(0)
            $item.Border.BorderBrush = [System.Windows.Media.Brushes]::Transparent

            if ($item.Id -eq $activeId) {
                $item.Border.Background = $activeBg
                if ($item.Text) {
                    $item.Text.Foreground = $activeFg
                    $item.Text.FontWeight = [System.Windows.FontWeights]::SemiBold
                }
                if ($item.Icon) {
                    $item.Icon.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#c15f3c")
                }
            } else {
                $item.Border.Background = $inactiveBg
                if ($item.Text) {
                    $item.Text.Foreground = $inactiveFg
                    $item.Text.FontWeight = [System.Windows.FontWeights]::SemiBold
                }
                if ($item.Icon) {
                    $item.Icon.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($item.OrigColor)
                }
            }
        }
    }

    # 1.5 Custom Pinned Quick Access items
    if ($PanelQuickAccessCustom) {
        foreach ($child in $PanelQuickAccessCustom.Children) {
            if ($child -is [System.Windows.Controls.Border]) {
                $childPath = if ($child.Tag) { $child.Tag.ToString().TrimEnd('\') } else { "" }
                $childId = "Pinned_" + $childPath
                $isSelected = ($childId.Equals($activeId, [System.StringComparison]::OrdinalIgnoreCase))
                $child.BorderThickness = [System.Windows.Thickness]::new(0)
                $child.BorderBrush = [System.Windows.Media.Brushes]::Transparent

                $grid = $child.Child
                if ($grid -is [System.Windows.Controls.Grid]) {
                    $tbIcon = $grid.Children | Where-Object { $_.Tag -eq "Icon" }
                    $tbLabel = $grid.Children | Where-Object { $_.Tag -eq "Label" }
                    if ($isSelected) {
                        $child.Background = $activeBg
                        if ($tbLabel) { $tbLabel.Foreground = $activeFg; $tbLabel.FontWeight = [System.Windows.FontWeights]::SemiBold }
                        if ($tbIcon) { $tbIcon.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#c15f3c") }
                    } else {
                        $child.Background = $inactiveBg
                        if ($tbLabel) { $tbLabel.Foreground = $inactiveFg; $tbLabel.FontWeight = [System.Windows.FontWeights]::SemiBold }
                        if ($tbIcon) { $tbIcon.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#A78BFA") }
                    }
                }
            }
        }
    }

    # 2. Partition Metric Tiles (ZeroHub Exact Style: #23232A activeBg, #c15f3c border, BorderThickness=1 ALWAYS)
    if ($PanelExplorerDriveButtons) {
        foreach ($child in $PanelExplorerDriveButtons.Children) {
            if ($child -is [System.Windows.Controls.Border]) {
                $tagLetter = if ($child.Tag) { $child.Tag.ToString().TrimEnd(':', '\') } else { "" }
                $driveKey = "Drive_" + $tagLetter
                $isSelected = ($driveKey.Equals($activeId, [System.StringComparison]::OrdinalIgnoreCase))

                # Thickness is PERMANENTLY 1px - NEVER changes so content never moves!
                $child.BorderThickness = [System.Windows.Thickness]::new(1)

                if ($isSelected) {
                    # Active Partition: Selected Card Style without aggressive outline
                    $child.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#202129")
                    $child.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#23232A")
                } else {
                    $child.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#111114")
                    $child.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#23232A")
                }
            }
        }
    }
}

function Update-SidebarSelectionForPath([string]$path) {
    if (-not $path) { return }

    $desktopPath   = [Environment]::GetFolderPath("Desktop").TrimEnd('\')
    $downloadsPath = (Join-Path $HOME "Downloads").TrimEnd('\')
    $documentsPath = [Environment]::GetFolderPath("MyDocuments").TrimEnd('\')
    $appDataPath   = $env:LOCALAPPDATA.TrimEnd('\')
    $tempPath      = [System.IO.Path]::GetTempPath().TrimEnd('\')

    $cleanPath = $path.TrimEnd('\')

    if ($cleanPath.Equals($desktopPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        Set-ActiveSidebarItem "Quick_Desktop"
        return
    }
    if ($cleanPath.Equals($downloadsPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        Set-ActiveSidebarItem "Quick_Downloads"
        return
    }
    if ($cleanPath.Equals($documentsPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        Set-ActiveSidebarItem "Quick_Documents"
        return
    }
    if ($cleanPath.Equals($appDataPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        Set-ActiveSidebarItem "Quick_AppData"
        return
    }
    if ($cleanPath.Equals($tempPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        Set-ActiveSidebarItem "Quick_Temp"
        return
    }

    # Check if path matches any custom pinned folder
    if ($Script:PinnedFolders) {
        foreach ($pinned in $Script:PinnedFolders) {
            if ($pinned -and $cleanPath.Equals([System.IO.Path]::GetFullPath($pinned).TrimEnd('\'), [System.StringComparison]::OrdinalIgnoreCase)) {
                Set-ActiveSidebarItem "Pinned_$cleanPath"
                return
            }
        }
    }

    # Otherwise match root drive partition
    try {
        $root = [System.IO.Path]::GetPathRoot($path)
        if ($root) {
            $driveLetter = $root.TrimEnd('\', ':')
            Set-ActiveSidebarItem "Drive_$driveLetter"
        }
    } catch {}
}

function Get-ActiveSidebarId {
    return $Script:CurrentActiveSidebarId
}

function Update-ExplorerDriveButtons {
    if (-not $PanelExplorerDriveButtons) { return }
    $PanelExplorerDriveButtons.Children.Clear()

    try {
        $drives = [System.IO.DriveInfo]::GetDrives()
        $readyCount = 0
        foreach ($d in $drives) {
            if ($d.IsReady -and $d.TotalSize -gt 0) {
                $readyCount++
                $driveLetter = $d.Name.TrimEnd('\')
                $driveRoot   = $d.RootDirectory.FullName

                $totalBytes = $d.TotalSize
                $freeBytes  = $d.AvailableFreeSpace
                $usedBytes  = $totalBytes - $freeBytes
                $percent    = [Math]::Round(($usedBytes / $totalBytes) * 100)
                $freeGB     = [Math]::Round($freeBytes / 1GB, 1)
                $totalGB    = [Math]::Round($totalBytes / 1GB, 1)
                $rawVol     = if ($d.VolumeLabel) { $d.VolumeLabel.Trim() } else { "" }
                $volLabel   = if ([string]::IsNullOrWhiteSpace($rawVol) -or $rawVol.Equals("New Volume", [System.StringComparison]::OrdinalIgnoreCase)) { "" } else { " ($rawVol)" }

                $cardBorder = New-Object System.Windows.Controls.Border
                $cardBorder.CornerRadius = [System.Windows.CornerRadius]::new(6)
                $cardBorder.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#111114")
                $cardBorder.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#23232A")
                $cardBorder.BorderThickness = [System.Windows.Thickness]::new(1)
                $cardBorder.Padding = [System.Windows.Thickness]::new(10, 8, 10, 8)
                $cardBorder.Margin = [System.Windows.Thickness]::new(0, 2, 0, 5)
                $cardBorder.Cursor = [System.Windows.Input.Cursors]::Hand
                $cardBorder.Tag = $driveLetter
                $cardBorder.ToolTip = "Drive ${driveLetter}$volLabel`n$freeGB GB Free of $totalGB GB ($percent% used)"

                $stack = New-Object System.Windows.Controls.StackPanel

                # Top Row: 2-Column Grid to guarantee no text collision
                $gridTop = New-Object System.Windows.Controls.Grid
                $gridTop.Margin = [System.Windows.Thickness]::new(0, 0, 0, 6)

                $colLeft = New-Object System.Windows.Controls.ColumnDefinition
                $colLeft.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
                $colRight = New-Object System.Windows.Controls.ColumnDefinition
                $colRight.Width = [System.Windows.GridLength]::Auto
                $gridTop.ColumnDefinitions.Add($colLeft) | Out-Null
                $gridTop.ColumnDefinitions.Add($colRight) | Out-Null

                $leftStack = New-Object System.Windows.Controls.DockPanel
                $leftStack.LastChildFill = $true
                [System.Windows.Controls.Grid]::SetColumn($leftStack, 0)
                $leftStack.VerticalAlignment = [System.Windows.VerticalAlignment]::Center

                $tbIcon = New-Object System.Windows.Controls.TextBlock
                $tbIcon.Text = [char]0xEDA2
                $tbIcon.FontFamily = New-Object System.Windows.Media.FontFamily("Segoe MDL2 Assets")
                $tbIcon.FontSize = 12
                $tbIcon.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#c15f3c")
                $tbIcon.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
                $tbIcon.Margin = [System.Windows.Thickness]::new(0, 0, 6, 0)
                [System.Windows.Controls.DockPanel]::SetDock($tbIcon, [System.Windows.Controls.Dock]::Left)
                $leftStack.Children.Add($tbIcon) | Out-Null

                $tbLabel = New-Object System.Windows.Controls.TextBlock
                $tbLabel.Text = "Drive ${driveLetter}$volLabel"
                $tbLabel.FontWeight = [System.Windows.FontWeights]::SemiBold
                $tbLabel.FontSize = 11
                $tbLabel.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#F5EDE0")
                $tbLabel.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
                $tbLabel.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis
                $leftStack.Children.Add($tbLabel) | Out-Null
                $gridTop.Children.Add($leftStack) | Out-Null

                $tbStorage = New-Object System.Windows.Controls.TextBlock
                $tbStorage.Text = "$freeGB GB free of $totalGB GB"
                $tbStorage.FontSize = 9.5
                $tbStorage.FontWeight = [System.Windows.FontWeights]::Bold
                $tbStorage.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#c15f3c")
                $tbStorage.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
                $tbStorage.Margin = [System.Windows.Thickness]::new(6, 0, 0, 0)
                [System.Windows.Controls.Grid]::SetColumn($tbStorage, 1)
                $gridTop.Children.Add($tbStorage) | Out-Null

                $stack.Children.Add($gridTop) | Out-Null

                # Bottom Row: Metric Progress Bar with Rounded Dark Track
                $trackBorder = New-Object System.Windows.Controls.Border
                $trackBorder.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#140F0C")
                $trackBorder.CornerRadius = [System.Windows.CornerRadius]::new(3)
                $trackBorder.Height = 5
                $trackBorder.SnapsToDevicePixels = $true

                $progBar = New-Object System.Windows.Controls.ProgressBar
                $progBar.Height = 5
                $progBar.Minimum = 0
                $progBar.Maximum = 100
                $progBar.Value = $percent
                $progBar.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#c15f3c")
                $progBar.Background = [System.Windows.Media.Brushes]::Transparent
                $progBar.BorderThickness = [System.Windows.Thickness]::new(0)
                $trackBorder.Child = $progBar

                $stack.Children.Add($trackBorder) | Out-Null
                $cardBorder.Child = $stack

                # Click Handler: Navigate into drive
                $targetRoot = $driveRoot
                $driveLetterTag = $driveLetter.TrimEnd(':')
                $driveId = "Drive_" + $driveLetterTag
                $cardBorder.add_MouseDown({
                    param($src, $ev)
                    if ($ev.ChangedButton -eq [System.Windows.Input.MouseButton]::Left) {
                        Show-ExplorerFilesView
                        Set-ActiveSidebarItem $driveId
                        Navigate-ExplorerFolder $targetRoot $true
                    }
                }.GetNewClosure())

                # Hover Handlers with dynamic active ID lookup (BorderThickness remains 1, no orange outline)
                $targetCard = $cardBorder
                $cardBorder.add_MouseEnter({
                    param($src, $ev)
                    $curr = Get-ActiveSidebarId
                    if ($curr -ne $driveId) {
                        $targetCard.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1A1A1F")
                        $targetCard.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#3A3A46")
                    } else {
                        $targetCard.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#262732")
                        $targetCard.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#3A3A46")
                    }
                    $targetCard.BorderThickness = [System.Windows.Thickness]::new(1)
                }.GetNewClosure())

                $cardBorder.add_MouseLeave({
                    param($src, $ev)
                    $curr = Get-ActiveSidebarId
                    if ($curr -ne $driveId) {
                        $targetCard.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#111114")
                        $targetCard.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#23232A")
                    } else {
                        $targetCard.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#202129")
                        $targetCard.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#23232A")
                    }
                    $targetCard.BorderThickness = [System.Windows.Thickness]::new(1)
                }.GetNewClosure())

                $PanelExplorerDriveButtons.Children.Add($cardBorder) | Out-Null
            }
        }

        if ($TxtDriveCountBadge) {
            $TxtDriveCountBadge.Text = "$readyCount PARTITIONS"
        }
    } catch {}

    Update-SidebarSelectionForPath $Script:ExplorerCurrentPath
}

# ==============================================================================
# WORKSTATION MULTI-PLACE TABS & HYPRLAND DYNAMIC TILING ENGINE
# ==============================================================================
$Script:WorkspaceTabs = New-Object System.Collections.Generic.List[PSObject]
$Script:ActiveWorkspaceId = $null
$Script:IsHyprlandTilingMode = $false
$Script:IsDraggingItem = $false

function Get-ActiveWorkspaceTab {
    if ($Script:WorkspaceTabs.Count -eq 0) { return $null }
    if ($Script:ActiveWorkspaceId) {
        $found = $Script:WorkspaceTabs | Where-Object { $_.Id -eq $Script:ActiveWorkspaceId } | Select-Object -First 1
        if ($found) { return $found }
    }
    return $Script:WorkspaceTabs[0]
}

function Get-WorkspaceTitleForPath([string]$path) {
    if ([string]::IsNullOrWhiteSpace($path)) { return "Workspace" }
    $p = $path.TrimEnd('\')
    if ($p.Length -le 2 -or $p -match '^[a-zA-Z]:$') {
        return "$p\"
    }
    $leaf = [System.IO.Path]::GetFileName($p)
    if ([string]::IsNullOrWhiteSpace($leaf)) { return $path }
    return $leaf
}

function Add-WorkspaceTab([string]$targetPath = $null, [bool]$switchTo = $true) {
    if ([string]::IsNullOrWhiteSpace($targetPath)) {
        if (-not [string]::IsNullOrWhiteSpace($Script:ExplorerCurrentPath)) {
            $targetPath = $Script:ExplorerCurrentPath
        } else {
            $targetPath = [Environment]::GetFolderPath([Environment+SpecialFolder]::Desktop)
            if (-not (Test-Path -LiteralPath $targetPath)) { $targetPath = "C:\" }
        }
    }

    try {
        if (Test-Path -LiteralPath $targetPath) {
            $targetPath = (Resolve-Path -LiteralPath $targetPath).Path
        }
    } catch {}

    $tabId = [System.Guid]::NewGuid().ToString("N").Substring(0, 8)
    $title = Get-WorkspaceTitleForPath $targetPath

    $history = New-Object System.Collections.Generic.List[string]
    $history.Add($targetPath)

    $tab = [PSCustomObject]@{
        Id            = $tabId
        Title         = $title
        Path          = $targetPath
        History       = $history
        HistoryIndex  = 0
        SortField     = "Name"
        SortAscending = $true
        Filter        = ""
        Items         = $null
    }

    $Script:WorkspaceTabs.Add($tab)

    if ($switchTo -or -not $Script:ActiveWorkspaceId) {
        Switch-WorkspaceTab $tabId
    } else {
        Render-WorkspaceTabs
        if ($Script:IsHyprlandTilingMode) {
            Update-HyprlandTilingLayout
        }
    }
    return
}

function Switch-WorkspaceTab([string]$tabId) {
    $tab = $Script:WorkspaceTabs | Where-Object { $_.Id -eq $tabId } | Select-Object -First 1
    if (-not $tab) { return }

    $Script:ActiveWorkspaceId = $tab.Id

    # Sync global navigation history to this tab's state
    $Script:ExplorerHistory = $tab.History
    $Script:ExplorerHistoryIndex = $tab.HistoryIndex
    $Script:CurrentSortField = $tab.SortField
    $Script:CurrentSortAscending = $tab.SortAscending

    if ($TxtExplorerFilter) {
        $TxtExplorerFilter.Text = if ($tab.Filter) { $tab.Filter } else { "" }
    }

    Render-WorkspaceTabs

    if ($Script:IsHyprlandTilingMode) {
        Highlight-ActiveHyprlandPane $tab.Id
        $TxtExplorerPath.Text = $tab.Path
        Update-NavigationButtonsState
        Update-SidebarSelectionForPath $tab.Path
    } else {
        # Navigate / refresh files in standard view
        Navigate-ExplorerFolder $tab.Path $false
    }
}

function Close-WorkspaceTab([string]$tabId) {
    if ($Script:WorkspaceTabs.Count -le 1) {
        # If last remaining tab, don't close, just reset to Home / C:
        return
    }

    $index = -1
    for ($i = 0; $i -lt $Script:WorkspaceTabs.Count; $i++) {
        if ($Script:WorkspaceTabs[$i].Id -eq $tabId) {
            $index = $i
            break
        }
    }
    if ($index -lt 0) { return }

    $wasActive = ($Script:ActiveWorkspaceId -eq $tabId)
    $Script:WorkspaceTabs.RemoveAt($index)

    if ($wasActive) {
        $newIndex = [Math]::Max(0, [Math]::Min($index, $Script:WorkspaceTabs.Count - 1))
        $nextTab = $Script:WorkspaceTabs[$newIndex]
        Switch-WorkspaceTab $nextTab.Id
    } else {
        Render-WorkspaceTabs
        if ($Script:IsHyprlandTilingMode) {
            Update-HyprlandTilingLayout
        }
    }
}

function Cycle-WorkspaceTab {
    if ($Script:WorkspaceTabs.Count -le 1) { return }
    $currentIndex = 0
    for ($i = 0; $i -lt $Script:WorkspaceTabs.Count; $i++) {
        if ($Script:WorkspaceTabs[$i].Id -eq $Script:ActiveWorkspaceId) {
            $currentIndex = $i
            break
        }
    }
    $nextIndex = ($currentIndex + 1) % $Script:WorkspaceTabs.Count
    Switch-WorkspaceTab $Script:WorkspaceTabs[$nextIndex].Id
}

function Render-WorkspaceTabs {
    if (-not $PanelWorkspaceTabList) { return }
    $PanelWorkspaceTabList.Children.Clear()

    foreach ($tab in $Script:WorkspaceTabs) {
        $isActive = ($tab.Id -eq $Script:ActiveWorkspaceId)

        $tabBorder = New-Object System.Windows.Controls.Border
        $tabBorder.CornerRadius = New-Object System.Windows.CornerRadius(6)
        $tabBorder.Padding = New-Object System.Windows.Thickness(8, 3, 6, 3)
        $tabBorder.Margin = New-Object System.Windows.Thickness(0, 0, 4, 0)
        $tabBorder.Cursor = [System.Windows.Input.Cursors]::Hand
        $tabBorder.ToolTip = $tab.Path
        $tabBorder.Tag = $tab.Id

        if ($isActive) {
            $tabBorder.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#2A1812")
            $tabBorder.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#c15f3c")
            $tabBorder.BorderThickness = New-Object System.Windows.Thickness(1)
        } else {
            $tabBorder.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#141419")
            $tabBorder.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#23232C")
            $tabBorder.BorderThickness = New-Object System.Windows.Thickness(1)
        }

        # Hover effects
        $tabBorder.add_MouseEnter({
            param($s, $e)
            if ($s.Tag -ne $Script:ActiveWorkspaceId) {
                $s.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1C1C24")
                $s.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#353542")
            }
        })
        $tabBorder.add_MouseLeave({
            param($s, $e)
            if ($s.Tag -ne $Script:ActiveWorkspaceId) {
                $s.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#141419")
                $s.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#23232C")
            }
        })

        $stack = New-Object System.Windows.Controls.StackPanel
        $stack.Orientation = [System.Windows.Controls.Orientation]::Horizontal
        $stack.VerticalAlignment = [System.Windows.VerticalAlignment]::Center

        # Tab Folder Icon
        $icon = New-Object System.Windows.Controls.TextBlock
        $icon.Text = [char]0xED25
        $icon.FontFamily = New-Object System.Windows.Media.FontFamily("Segoe MDL2 Assets")
        $icon.FontSize = 11.5
        $icon.Foreground = if ($isActive) {
            [System.Windows.Media.BrushConverter]::new().ConvertFromString("#c15f3c")
        } else {
            [System.Windows.Media.BrushConverter]::new().ConvertFromString("#8E8E98")
        }
        $icon.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        $icon.Margin = New-Object System.Windows.Thickness(0, 0, 5, 0)
        $stack.Children.Add($icon) | Out-Null

        # Tab Title
        $titleTxt = New-Object System.Windows.Controls.TextBlock
        $titleTxt.Text = $tab.Title
        $titleTxt.FontSize = 11
        $titleTxt.FontWeight = if ($isActive) { [System.Windows.FontWeights]::Bold } else { [System.Windows.FontWeights]::SemiBold }
        $titleTxt.Foreground = if ($isActive) {
            [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FFFFFF")
        } else {
            [System.Windows.Media.BrushConverter]::new().ConvertFromString("#A1A1AA")
        }
        $titleTxt.MaxWidth = 130
        $titleTxt.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis
        $titleTxt.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        $titleTxt.Margin = New-Object System.Windows.Thickness(0, 0, 6, 0)
        $stack.Children.Add($titleTxt) | Out-Null

        # Close Button
        $closeBorder = New-Object System.Windows.Controls.Border
        $closeBorder.Width = 16
        $closeBorder.Height = 16
        $closeBorder.CornerRadius = New-Object System.Windows.CornerRadius(3)
        $closeBorder.Background = [System.Windows.Media.Brushes]::Transparent
        $closeBorder.Cursor = [System.Windows.Input.Cursors]::Hand
        $closeBorder.ToolTip = "Close Tab (Ctrl+W)"

        $closeTxt = New-Object System.Windows.Controls.TextBlock
        $closeTxt.Text = [char]0xE711
        $closeTxt.FontFamily = New-Object System.Windows.Media.FontFamily("Segoe MDL2 Assets")
        $closeTxt.FontSize = 8.5
        $closeTxt.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#71717A")
        $closeTxt.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
        $closeTxt.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        $closeBorder.Child = $closeTxt

        $closeBorder.add_MouseEnter({
            param($s, $e)
            $s.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#4A1818")
            $s.Child.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FF6B6B")
        })
        $closeBorder.add_MouseLeave({
            param($s, $e)
            $s.Background = [System.Windows.Media.Brushes]::Transparent
            $s.Child.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#71717A")
        })

        $targetTabId = $tab.Id
        $closeBorder.add_MouseLeftButtonUp({
            param($s, $e)
            $e.Handled = $true
            Close-WorkspaceTab $targetTabId
        }.GetNewClosure())

        $stack.Children.Add($closeBorder) | Out-Null
        $tabBorder.Child = $stack

        # Tab Click & Middle Click
        $tabBorder.add_MouseLeftButtonUp({
            param($s, $e)
            Switch-WorkspaceTab $targetTabId
        }.GetNewClosure())

        $tabBorder.add_MouseUp({
            param($s, $e)
            if ($e.ChangedButton -eq [System.Windows.Input.MouseButton]::Middle) {
                Close-WorkspaceTab $targetTabId
            }
        }.GetNewClosure())

        $PanelWorkspaceTabList.Children.Add($tabBorder) | Out-Null
    }
}

function Toggle-HyprlandTilingMode {
    $Script:IsHyprlandTilingMode = -not $Script:IsHyprlandTilingMode

    if ($Script:IsHyprlandTilingMode) {
        # Hyprland Tiling ON
        if ($PanelExplorerSingleView) { $PanelExplorerSingleView.Visibility = [System.Windows.Visibility]::Collapsed }
        if ($PanelTilingHost) { $PanelTilingHost.Visibility = [System.Windows.Visibility]::Visible }

        if ($BadgeTilingStatus) {
            $BadgeTilingStatus.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#38170D")
            $BadgeTilingStatus.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#c15f3c")
        }
        if ($TxtBadgeTilingStatus) {
            $TxtBadgeTilingStatus.Text = "TILED"
            $TxtBadgeTilingStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FF8C61")
        }
        if ($IconTilingGlyph) {
            $IconTilingGlyph.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FF7744")
        }

        # If user only has 1 tab open, automatically open a 2nd workspace (e.g. Downloads or Desktop)
        # so they immediately see the dual tiling magic without needing to click anything!
        if ($Script:WorkspaceTabs.Count -lt 2) {
            $secondPath = [Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile) + "\Downloads"
            if (-not (Test-Path -LiteralPath $secondPath) -or $secondPath -eq $Script:WorkspaceTabs[0].Path) {
                $secondPath = [Environment]::GetFolderPath([Environment+SpecialFolder]::Desktop)
            }
            if (-not (Test-Path -LiteralPath $secondPath) -or $secondPath -eq $Script:WorkspaceTabs[0].Path) {
                $secondPath = "C:\"
            }
            Add-WorkspaceTab $secondPath $false
        }

        Update-HyprlandTilingLayout
    } else {
        # Hyprland Tiling OFF
        if ($PanelTilingHost) { $PanelTilingHost.Visibility = [System.Windows.Visibility]::Collapsed }
        if ($PanelExplorerSingleView) { $PanelExplorerSingleView.Visibility = [System.Windows.Visibility]::Visible }

        if ($BadgeTilingStatus) {
            $BadgeTilingStatus.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1C1816")
            $BadgeTilingStatus.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#c15f3c")
        }
        if ($TxtBadgeTilingStatus) {
            $TxtBadgeTilingStatus.Text = "OFF"
            $TxtBadgeTilingStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#A1A1AA")
        }
        if ($IconTilingGlyph) {
            $IconTilingGlyph.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#c15f3c")
        }

        # Restore active workspace in single view
        $activeTab = Get-ActiveWorkspaceTab
        if ($activeTab) {
            Navigate-ExplorerFolder $activeTab.Path $false
        }
    }
}

function Create-HyprlandPaneControl($tab) {
    $paneXamlTemplate = @'
<Border xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Name="PaneBorder" CornerRadius="8" Background="#111114" BorderBrush="#22222A" BorderThickness="1" Margin="3" AllowDrop="True">
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="32" />
            <RowDefinition Height="*" />
        </Grid.RowDefinitions>
        <Border Grid.Row="0" Name="HeaderBorder" Background="#141418" CornerRadius="6,6,0,0" Padding="8,0">
            <DockPanel LastChildFill="True">
                <StackPanel Orientation="Horizontal" DockPanel.Dock="Right" VerticalAlignment="Center">
                    <Button Name="BtnPaneUp" Width="22" Height="22" Background="Transparent" BorderThickness="0" Cursor="Hand" ToolTip="Parent Directory">
                        <TextBlock Text="&#xE74A;" FontFamily="Segoe MDL2 Assets" FontSize="10" Foreground="#F5EDE0" />
                    </Button>
                    <Button Name="BtnPaneRefresh" Width="22" Height="22" Background="Transparent" BorderThickness="0" Cursor="Hand" Margin="2,0" ToolTip="Refresh">
                        <TextBlock Text="&#xE72C;" FontFamily="Segoe MDL2 Assets" FontSize="10" Foreground="#4ADE80" />
                    </Button>
                    <Button Name="BtnPaneClose" Width="22" Height="22" Background="Transparent" BorderThickness="0" Cursor="Hand" ToolTip="Close Pane">
                        <TextBlock Text="&#xE711;" FontFamily="Segoe MDL2 Assets" FontSize="9.5" Foreground="#EF4444" />
                    </Button>
                </StackPanel>
                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                    <TextBlock Text="&#xED25;" FontFamily="Segoe MDL2 Assets" FontSize="12" Foreground="#c15f3c" Margin="0,0,6,0" VerticalAlignment="Center" />
                    <TextBlock Name="TxtPaneTitle" Text="Folder" FontWeight="Bold" FontSize="11" Foreground="#F5EDE0" VerticalAlignment="Center" />
                    <Border Name="BadgePaneActive" Background="#38170D" BorderBrush="#c15f3c" BorderThickness="1" CornerRadius="4" Padding="4,1" Margin="6,0,0,0" VerticalAlignment="Center" Visibility="Collapsed">
                        <TextBlock Text="ACTIVE" FontSize="8" FontWeight="Bold" Foreground="#FF8C61" />
                    </Border>
                    <TextBlock Name="TxtPanePath" FontSize="9.5" Foreground="#71717A" Margin="6,0,0,0" Text="" TextTrimming="CharacterEllipsis" MaxWidth="160" VerticalAlignment="Center" />
                    <TextBlock Name="TxtPaneCount" Text="(0 items)" FontSize="9.5" Foreground="#71717A" Margin="6,0,0,0" VerticalAlignment="Center" />
                </StackPanel>
            </DockPanel>
        </Border>
        <DataGrid Grid.Row="1" Name="PaneDataGrid" Background="#111114" Foreground="#FFFFFF" BorderThickness="0"
                  GridLinesVisibility="All" HorizontalGridLinesBrush="#16171E" VerticalGridLinesBrush="#16171E"
                  AutoGenerateColumns="False" CanUserAddRows="False" IsReadOnly="True"
                  HeadersVisibility="Column" SelectionMode="Extended" SelectionUnit="FullRow"
                  RowHeight="28" FontSize="11"
                  ScrollViewer.CanContentScroll="True" ScrollViewer.HorizontalScrollBarVisibility="Disabled" ScrollViewer.VerticalScrollBarVisibility="Auto">
            <DataGrid.Resources>
                <Style TargetType="{x:Type DataGridColumnHeader}">
                    <Setter Property="Background" Value="#141418" />
                    <Setter Property="Foreground" Value="#c15f3c" />
                    <Setter Property="FontWeight" Value="Bold" />
                    <Setter Property="FontSize" Value="10.5" />
                    <Setter Property="Padding" Value="8,4" />
                    <Setter Property="BorderBrush" Value="#1E1E26" />
                    <Setter Property="BorderThickness" Value="0,0,1,1" />
                </Style>
                <Style TargetType="{x:Type DataGridRow}">
                    <Setter Property="Background" Value="#111114" />
                    <Setter Property="Foreground" Value="#F5EDE0" />
                    <Style.Triggers>
                        <Trigger Property="IsSelected" Value="True">
                            <Setter Property="Background" Value="#1E242C" />
                        </Trigger>
                        <Trigger Property="IsMouseOver" Value="True">
                            <Setter Property="Background" Value="#181820" />
                        </Trigger>
                    </Style.Triggers>
                </Style>
                <Style TargetType="{x:Type DataGridCell}">
                    <Setter Property="BorderThickness" Value="0" />
                    <Setter Property="Padding" Value="4,2" />
                    <Setter Property="FocusVisualStyle" Value="{x:Null}" />
                    <Setter Property="Template">
                        <Setter.Value>
                            <ControlTemplate TargetType="{x:Type DataGridCell}">
                                <Border Background="{TemplateBinding Background}" BorderThickness="0" Padding="{TemplateBinding Padding}">
                                    <ContentPresenter VerticalAlignment="Center" />
                                </Border>
                            </ControlTemplate>
                        </Setter.Value>
                    </Setter>
                    <Style.Triggers>
                        <Trigger Property="IsSelected" Value="True">
                            <Setter Property="Background" Value="#1E242C" />
                            <Setter Property="Foreground" Value="#FFFFFF" />
                        </Trigger>
                    </Style.Triggers>
                </Style>
            </DataGrid.Resources>
            <DataGrid.Columns>
                <DataGridTemplateColumn Header="Name" Width="*" MinWidth="100">
                    <DataGridTemplateColumn.CellTemplate>
                        <DataTemplate>
                            <StackPanel Orientation="Horizontal" VerticalAlignment="Center" Margin="6,0">
                                <Grid Width="16" Height="16" Margin="0,0,6,0">
                                    <Image Source="{Binding IconImage}" Width="16" Height="16" Stretch="Uniform">
                                        <Image.Style>
                                            <Style TargetType="Image">
                                                <Setter Property="Visibility" Value="Collapsed" />
                                                <Style.Triggers>
                                                    <DataTrigger Binding="{Binding HasIconImage}" Value="True">
                                                        <Setter Property="Visibility" Value="Visible" />
                                                    </DataTrigger>
                                                </Style.Triggers>
                                            </Style>
                                        </Image.Style>
                                    </Image>
                                    <TextBlock Text="{Binding IconSymbol}" FontFamily="Segoe MDL2 Assets" FontSize="12" Foreground="{Binding IconColor}" VerticalAlignment="Center" HorizontalAlignment="Center">
                                        <TextBlock.Style>
                                            <Style TargetType="TextBlock">
                                                <Setter Property="Visibility" Value="Collapsed" />
                                                <Style.Triggers>
                                                    <DataTrigger Binding="{Binding HasIconImage}" Value="False">
                                                        <Setter Property="Visibility" Value="Visible" />
                                                    </DataTrigger>
                                                </Style.Triggers>
                                            </Style>
                                        </TextBlock.Style>
                                    </TextBlock>
                                </Grid>
                                <TextBlock Text="{Binding Name}" FontWeight="SemiBold" FontSize="11" Foreground="#F5EDE0" VerticalAlignment="Center" TextTrimming="CharacterEllipsis" />
                            </StackPanel>
                        </DataTemplate>
                    </DataGridTemplateColumn.CellTemplate>
                </DataGridTemplateColumn>
                <DataGridTemplateColumn Header="Size" Width="70">
                    <DataGridTemplateColumn.CellTemplate>
                        <DataTemplate>
                            <TextBlock Text="{Binding SizeFormatted}" FontFamily="Consolas, monospace" FontSize="10.5" Foreground="#38BDF8" HorizontalAlignment="Right" VerticalAlignment="Center" Margin="0,0,8,0" />
                        </DataTemplate>
                    </DataGridTemplateColumn.CellTemplate>
                </DataGridTemplateColumn>
                <DataGridTemplateColumn Header="Type" Width="75">
                    <DataGridTemplateColumn.CellTemplate>
                        <DataTemplate>
                            <Border Background="#161720" BorderBrush="#242634" BorderThickness="1" CornerRadius="3" Padding="4,1" HorizontalAlignment="Left" VerticalAlignment="Center">
                                <TextBlock Text="{Binding ItemType}" Foreground="#94A3B8" FontSize="9.5" VerticalAlignment="Center" TextTrimming="CharacterEllipsis" />
                            </Border>
                        </DataTemplate>
                    </DataGridTemplateColumn.CellTemplate>
                </DataGridTemplateColumn>
                <DataGridTemplateColumn Header="Date" Width="105">
                    <DataGridTemplateColumn.CellTemplate>
                        <DataTemplate>
                            <TextBlock Text="{Binding DateModifiedFormatted}" FontSize="10" Foreground="#64748B" VerticalAlignment="Center" Margin="4,0" />
                        </DataTemplate>
                    </DataGridTemplateColumn.CellTemplate>
                </DataGridTemplateColumn>
            </DataGrid.Columns>
        </DataGrid>
    </Grid>
</Border>
'@

    $paneBorder = [System.Windows.Markup.XamlReader]::Parse($paneXamlTemplate)
    $paneBorder.Tag = $tab.Id

    $txtTitle = $paneBorder.FindName("TxtPaneTitle")
    if ($txtTitle) { $txtTitle.Text = $tab.Title }

    $txtPath = $paneBorder.FindName("TxtPanePath")
    if ($txtPath) { $txtPath.Text = $tab.Path; $txtPath.ToolTip = $tab.Path }

    $btnUp = $paneBorder.FindName("BtnPaneUp")
    $btnRefresh = $paneBorder.FindName("BtnPaneRefresh")
    $btnClose = $paneBorder.FindName("BtnPaneClose")
    $grid = $paneBorder.FindName("PaneDataGrid")

    $targetTab = $tab

    # Click / Focus on pane sets active workspace
    $paneBorder.add_PreviewMouseDown({
        param($s, $e)
        if ($Script:ActiveWorkspaceId -ne $targetTab.Id) {
            Switch-WorkspaceTab $targetTab.Id
        }
    })

    if ($btnUp) {
        $btnUp.add_Click({
            param($s, $e)
            $parent = [System.IO.Path]::GetDirectoryName($targetTab.Path)
            if (-not [string]::IsNullOrEmpty($parent)) {
                Navigate-HyprlandPane $paneBorder $targetTab $parent
            }
        })
    }

    if ($btnRefresh) {
        $btnRefresh.add_Click({
            param($s, $e)
            Navigate-HyprlandPane $paneBorder $targetTab $targetTab.Path
        })
    }

    if ($btnClose) {
        $btnClose.add_Click({
            param($s, $e)
            Close-WorkspaceTab $targetTab.Id
        })
    }

    if ($grid) {
        # Double Click to open or navigate
        $grid.add_MouseDoubleClick({
            param($s, $e)
            $selected = $grid.SelectedItem
            if ($selected -and -not $selected.IsBanner) {
                if ($selected.IsDirectory) {
                    Navigate-HyprlandPane $paneBorder $targetTab $selected.FullPath
                } else {
                    [ZeroExplore.ShellNative]::OpenFileNative($selected.FullPath)
                }
            }
        })

        # Selection Changed updates preview and active tab
        $grid.add_SelectionChanged({
            param($s, $e)
            $selected = $grid.SelectedItem
            if ($selected -and -not $selected.IsBanner) {
                if ($Script:ActiveWorkspaceId -ne $targetTab.Id) {
                    Switch-WorkspaceTab $targetTab.Id
                }
                Update-LivePreviewForPath $selected.FullPath $selected.IsDirectory
            }
        })

        # Inter-pane Drag & Drop: Drag Source
        $grid.add_PreviewMouseMove({
            param($s, $e)
            if ($e.LeftButton -eq [System.Windows.Input.MouseButtonState]::Pressed -and -not $Script:IsDraggingItem) {
                $selected = @($grid.SelectedItems)
                if ($selected.Count -gt 0) {
                    $paths = [System.Collections.Specialized.StringCollection]::new()
                    foreach ($item in $selected) {
                        if ($item.FullPath) { [void]$paths.Add($item.FullPath) }
                    }
                    if ($paths.Count -gt 0) {
                        $Script:IsDraggingItem = $true
                        try {
                            $data = New-Object System.Windows.DataObject
                            $data.SetFileDropList($paths)
                            [System.Windows.DragDrop]::DoDragDrop($grid, $data, [System.Windows.DragDropEffects]::Copy -bor [System.Windows.DragDropEffects]::Move)
                        } finally {
                            $Script:IsDraggingItem = $false
                        }
                    }
                }
            }
        })
    }

    # Inter-pane Drag & Drop: Drop Target
    $paneBorder.Add_DragOver({
        param($s, $e)
        if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
            $e.Effects = [System.Windows.DragDropEffects]::Copy
            $e.Handled = $true
        }
    })

    $paneBorder.Add_Drop({
        param($s, $e)
        if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
            $dropped = $e.Data.GetData([System.Windows.DataFormats]::FileDrop)
            if ($dropped -and $dropped.Length -gt 0) {
                $targetDir = $targetTab.Path
                $copiedCount = 0
                foreach ($item in $dropped) {
                    try {
                        Copy-Item -LiteralPath $item -Destination $targetDir -Recurse -Force -ErrorAction SilentlyContinue
                        $copiedCount++
                    } catch {}
                }
                # Refresh all open tiled panes
                foreach ($child in $PanelTilingHost.Children) {
                    if ($child.Tag) {
                        $t = $Script:WorkspaceTabs | Where-Object { $_.Id -eq $child.Tag } | Select-Object -First 1
                        if ($t) { Navigate-HyprlandPane $child $t $t.Path }
                    }
                }
                if ($TxtExplorerStatusCount) {
                    $TxtExplorerStatusCount.Text = "Copied $copiedCount item(s) to $($targetTab.Title)"
                }
            }
            $e.Handled = $true
        }
    })

    # Initial load of pane items
    Navigate-HyprlandPane $paneBorder $targetTab $targetTab.Path

    return $paneBorder
}

function Navigate-HyprlandPane($paneBorder, $tab, [string]$newPath) {
    if ([string]::IsNullOrWhiteSpace($newPath) -or -not (Test-Path -LiteralPath $newPath)) { return }
    try {
        $resolved = (Resolve-Path -LiteralPath $newPath).Path
    } catch {
        $resolved = $newPath
    }

    $tab.Path = $resolved
    $tab.Title = Get-WorkspaceTitleForPath $resolved
    if (-not $tab.History) { $tab.History = New-Object System.Collections.Generic.List[string] }
    if ($tab.History.Count -eq 0 -or $tab.History[$tab.History.Count - 1] -ne $resolved) {
        $tab.History.Add($resolved)
        $tab.HistoryIndex = $tab.History.Count - 1
    }

    $items = [ZeroExplore.FileExplorerEngine]::GetDirectoryItems($resolved)
    $tab.Items = $items

    # Update pane header
    $txtTitle = $paneBorder.FindName("TxtPaneTitle")
    if ($txtTitle) { $txtTitle.Text = $tab.Title }
    $txtPath = $paneBorder.FindName("TxtPanePath")
    if ($txtPath) { $txtPath.Text = $tab.Path; $txtPath.ToolTip = $tab.Path }

    $totalItems = 0
    $totalBytes = 0
    foreach ($it in $items) {
        if (-not $it.IsBanner) {
            $totalItems++
            if (-not $it.IsDirectory) { $totalBytes += $it.SizeBytes }
        }
    }
    $sizeFormatted = [ZeroExplore.FileExplorerEngine]::FormatSize($totalBytes)
    $txtCount = $paneBorder.FindName("TxtPaneCount")
    if ($txtCount) { $txtCount.Text = "($totalItems items)" }

    $grid = $paneBorder.FindName("PaneDataGrid")
    if ($grid) {
        $sortedItems = [ZeroExplore.FileExplorerEngine]::SortItems($items, $tab.SortField, $tab.SortAscending)
        $grid.ItemsSource = $sortedItems
    }

    Render-WorkspaceTabs

    if ($Script:ActiveWorkspaceId -eq $tab.Id) {
        $TxtExplorerPath.Text = $resolved
        Update-NavigationButtonsState
        Update-SidebarSelectionForPath $resolved
        $TxtExplorerStatusCount.Text = "$totalItems items ($sizeFormatted)"
    }
}

function Highlight-ActiveHyprlandPane([string]$tabId) {
    if (-not $PanelTilingHost) { return }
    foreach ($child in $PanelTilingHost.Children) {
        if ($child -is [System.Windows.Controls.Border]) {
            $isThisActive = ($child.Tag -eq $tabId)
            $child.BorderBrush = if ($isThisActive) { [System.Windows.Media.BrushConverter]::new().ConvertFromString("#c15f3c") } else { [System.Windows.Media.BrushConverter]::new().ConvertFromString("#22222A") }
            $child.BorderThickness = if ($isThisActive) { New-Object System.Windows.Thickness(2) } else { New-Object System.Windows.Thickness(1) }

            $header = $child.FindName("HeaderBorder")
            if ($header) {
                $header.Background = if ($isThisActive) { [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1E1614") } else { [System.Windows.Media.BrushConverter]::new().ConvertFromString("#141418") }
            }
            $badge = $child.FindName("BadgePaneActive")
            if ($badge) {
                $badge.Visibility = if ($isThisActive) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
            }
        }
    }
}

function Update-HyprlandTilingLayout {
    if (-not $PanelTilingHost) { return }
    $PanelTilingHost.Children.Clear()
    $PanelTilingHost.ColumnDefinitions.Clear()
    $PanelTilingHost.RowDefinitions.Clear()

    $count = $Script:WorkspaceTabs.Count
    if ($count -le 0) { return }

    if ($count -eq 1) {
        $col = New-Object System.Windows.Controls.ColumnDefinition
        $col.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
        $PanelTilingHost.ColumnDefinitions.Add($col)

        $row = New-Object System.Windows.Controls.RowDefinition
        $row.Height = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
        $PanelTilingHost.RowDefinitions.Add($row)

        $pane = Create-HyprlandPaneControl $Script:WorkspaceTabs[0]
        [System.Windows.Controls.Grid]::SetColumn($pane, 0)
        [System.Windows.Controls.Grid]::SetRow($pane, 0)
        $PanelTilingHost.Children.Add($pane) | Out-Null
    } elseif ($count -eq 2) {
        # 2-Pane Split (50/50) with interactive Splitter
        $col0 = New-Object System.Windows.Controls.ColumnDefinition
        $col0.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
        $colS = New-Object System.Windows.Controls.ColumnDefinition
        $colS.Width = [System.Windows.GridLength]::Auto
        $col1 = New-Object System.Windows.Controls.ColumnDefinition
        $col1.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)

        $PanelTilingHost.ColumnDefinitions.Add($col0)
        $PanelTilingHost.ColumnDefinitions.Add($colS)
        $PanelTilingHost.ColumnDefinitions.Add($col1)

        $row = New-Object System.Windows.Controls.RowDefinition
        $row.Height = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
        $PanelTilingHost.RowDefinitions.Add($row)

        $pane0 = Create-HyprlandPaneControl $Script:WorkspaceTabs[0]
        [System.Windows.Controls.Grid]::SetColumn($pane0, 0)
        [System.Windows.Controls.Grid]::SetRow($pane0, 0)
        $PanelTilingHost.Children.Add($pane0) | Out-Null

        $splitter = New-Object System.Windows.Controls.GridSplitter
        $splitter.Width = 5
        $splitter.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
        $splitter.VerticalAlignment = [System.Windows.VerticalAlignment]::Stretch
        $splitter.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#181820")
        $splitter.ShowsPreview = $false
        $splitter.ResizeDirection = [System.Windows.Controls.GridResizeDirection]::Columns
        $splitter.Cursor = [System.Windows.Input.Cursors]::SizeWE
        [System.Windows.Controls.Grid]::SetColumn($splitter, 1)
        [System.Windows.Controls.Grid]::SetRow($splitter, 0)
        $PanelTilingHost.Children.Add($splitter) | Out-Null

        $pane1 = Create-HyprlandPaneControl $Script:WorkspaceTabs[1]
        [System.Windows.Controls.Grid]::SetColumn($pane1, 2)
        [System.Windows.Controls.Grid]::SetRow($pane1, 0)
        $PanelTilingHost.Children.Add($pane1) | Out-Null
    } elseif ($count -eq 3) {
        # Hyprland Master-Stack: Master on left (55%), Stack of 2 on right (45%)
        $col0 = New-Object System.Windows.Controls.ColumnDefinition
        $col0.Width = New-Object System.Windows.GridLength(1.15, [System.Windows.GridUnitType]::Star)
        $colS = New-Object System.Windows.Controls.ColumnDefinition
        $colS.Width = [System.Windows.GridLength]::Auto
        $col1 = New-Object System.Windows.Controls.ColumnDefinition
        $col1.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)

        $PanelTilingHost.ColumnDefinitions.Add($col0)
        $PanelTilingHost.ColumnDefinitions.Add($colS)
        $PanelTilingHost.ColumnDefinitions.Add($col1)

        $row = New-Object System.Windows.Controls.RowDefinition
        $row.Height = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
        $PanelTilingHost.RowDefinitions.Add($row)

        # Master Pane (Column 0)
        $pane0 = Create-HyprlandPaneControl $Script:WorkspaceTabs[0]
        [System.Windows.Controls.Grid]::SetColumn($pane0, 0)
        [System.Windows.Controls.Grid]::SetRow($pane0, 0)
        $PanelTilingHost.Children.Add($pane0) | Out-Null

        # Splitter (Column 1)
        $splitter = New-Object System.Windows.Controls.GridSplitter
        $splitter.Width = 5
        $splitter.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
        $splitter.VerticalAlignment = [System.Windows.VerticalAlignment]::Stretch
        $splitter.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#181820")
        $splitter.ShowsPreview = $false
        $splitter.ResizeDirection = [System.Windows.Controls.GridResizeDirection]::Columns
        $splitter.Cursor = [System.Windows.Input.Cursors]::SizeWE
        [System.Windows.Controls.Grid]::SetColumn($splitter, 1)
        [System.Windows.Controls.Grid]::SetRow($splitter, 0)
        $PanelTilingHost.Children.Add($splitter) | Out-Null

        # Right Stack Grid (Column 2)
        $stackGrid = New-Object System.Windows.Controls.Grid
        $sRow0 = New-Object System.Windows.Controls.RowDefinition
        $sRow0.Height = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
        $sRowS = New-Object System.Windows.Controls.RowDefinition
        $sRowS.Height = [System.Windows.GridLength]::Auto
        $sRow1 = New-Object System.Windows.Controls.RowDefinition
        $sRow1.Height = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
        $stackGrid.RowDefinitions.Add($sRow0)
        $stackGrid.RowDefinitions.Add($sRowS)
        $stackGrid.RowDefinitions.Add($sRow1)

        $pane1 = Create-HyprlandPaneControl $Script:WorkspaceTabs[1]
        [System.Windows.Controls.Grid]::SetRow($pane1, 0)
        $stackGrid.Children.Add($pane1) | Out-Null

        $stackSplitter = New-Object System.Windows.Controls.GridSplitter
        $stackSplitter.Height = 5
        $stackSplitter.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Stretch
        $stackSplitter.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        $stackSplitter.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#181820")
        $stackSplitter.ShowsPreview = $false
        $stackSplitter.ResizeDirection = [System.Windows.Controls.GridResizeDirection]::Rows
        $stackSplitter.Cursor = [System.Windows.Input.Cursors]::SizeNS
        [System.Windows.Controls.Grid]::SetRow($stackSplitter, 1)
        $stackGrid.Children.Add($stackSplitter) | Out-Null

        $pane2 = Create-HyprlandPaneControl $Script:WorkspaceTabs[2]
        [System.Windows.Controls.Grid]::SetRow($pane2, 2)
        $stackGrid.Children.Add($pane2) | Out-Null

        [System.Windows.Controls.Grid]::SetColumn($stackGrid, 2)
        [System.Windows.Controls.Grid]::SetRow($stackGrid, 0)
        $PanelTilingHost.Children.Add($stackGrid) | Out-Null
    } else {
        # 4+ Panes: 2 Columns with dynamic rows
        $col0 = New-Object System.Windows.Controls.ColumnDefinition
        $col0.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
        $colS = New-Object System.Windows.Controls.ColumnDefinition
        $colS.Width = [System.Windows.GridLength]::Auto
        $col1 = New-Object System.Windows.Controls.ColumnDefinition
        $col1.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
        $PanelTilingHost.ColumnDefinitions.Add($col0)
        $PanelTilingHost.ColumnDefinitions.Add($colS)
        $PanelTilingHost.ColumnDefinitions.Add($col1)

        $numRows = [Math]::Ceiling($count / 2.0)
        for ($r = 0; $r -lt $numRows; $r++) {
            $rowDef = New-Object System.Windows.Controls.RowDefinition
            $rowDef.Height = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
            $PanelTilingHost.RowDefinitions.Add($rowDef)
            if ($r -lt ($numRows - 1)) {
                $rowSep = New-Object System.Windows.Controls.RowDefinition
                $rowSep.Height = [System.Windows.GridLength]::Auto
                $PanelTilingHost.RowDefinitions.Add($rowSep)
            }
        }

        $colSplitter = New-Object System.Windows.Controls.GridSplitter
        $colSplitter.Width = 5
        $colSplitter.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
        $colSplitter.VerticalAlignment = [System.Windows.VerticalAlignment]::Stretch
        $colSplitter.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#181820")
        $colSplitter.ShowsPreview = $false
        $colSplitter.ResizeDirection = [System.Windows.Controls.GridResizeDirection]::Columns
        $colSplitter.Cursor = [System.Windows.Input.Cursors]::SizeWE
        [System.Windows.Controls.Grid]::SetColumn($colSplitter, 1)
        [System.Windows.Controls.Grid]::SetRow($colSplitter, 0)
        [System.Windows.Controls.Grid]::SetRowSpan($colSplitter, $PanelTilingHost.RowDefinitions.Count)
        $PanelTilingHost.Children.Add($colSplitter) | Out-Null

        for ($idx = 0; $idx -lt $count; $idx++) {
            $pane = Create-HyprlandPaneControl $Script:WorkspaceTabs[$idx]
            $gridCol = if (($idx % 2) -eq 0) { 0 } else { 2 }
            $gridRow = [Math]::Floor($idx / 2.0) * 2
            [System.Windows.Controls.Grid]::SetColumn($pane, $gridCol)
            [System.Windows.Controls.Grid]::SetRow($pane, $gridRow)
            $PanelTilingHost.Children.Add($pane) | Out-Null
        }
    }

    Highlight-ActiveHyprlandPane $Script:ActiveWorkspaceId
}

# ==============================================================================
# FILE SYSTEM NAVIGATION
# ==============================================================================
function Navigate-ExplorerFolder([string]$targetPath, [bool]$recordHistory = $true) {
    if ([string]::IsNullOrWhiteSpace($targetPath)) { return }
    if (-not (Test-Path -LiteralPath $targetPath)) {
        [System.Windows.MessageBox]::Show("The directory could not be found:`n$targetPath", "ZeroExplore - Path Error", "OK", "Warning")
        return
    }

    try {
        $resolved = (Resolve-Path -LiteralPath $targetPath).Path
    } catch {
        $resolved = $targetPath
    }

    $Script:ExplorerCurrentPath = $resolved
    $TxtExplorerPath.Text = $resolved

    # Sync Active Workstation Tab Path & Title
    $activeTab = Get-ActiveWorkspaceTab
    if ($activeTab) {
        $activeTab.Path = $resolved
        $activeTab.Title = Get-WorkspaceTitleForPath $resolved
        Render-WorkspaceTabs
    }

    if ($recordHistory) {
        $shouldAdd = ($Script:ExplorerHistory.Count -eq 0)
        if (-not $shouldAdd) {
            if ($Script:ExplorerHistoryIndex -ge 0 -and $Script:ExplorerHistoryIndex -lt $Script:ExplorerHistory.Count) {
                $shouldAdd = ($Script:ExplorerHistory[$Script:ExplorerHistoryIndex] -ne $resolved)
            } else {
                $shouldAdd = $true
            }
        }

        if ($shouldAdd) {
            if ($Script:ExplorerHistoryIndex -ge 0 -and $Script:ExplorerHistoryIndex -lt ($Script:ExplorerHistory.Count - 1)) {
                $removeCount = $Script:ExplorerHistory.Count - 1 - $Script:ExplorerHistoryIndex
                $Script:ExplorerHistory.RemoveRange($Script:ExplorerHistoryIndex + 1, $removeCount)
            }
            $Script:ExplorerHistory.Add($resolved)
            $Script:ExplorerHistoryIndex = $Script:ExplorerHistory.Count - 1
        }
    }

    Update-NavigationButtonsState
    Update-SidebarSelectionForPath $resolved
    Refresh-ExplorerCurrentDirectory
}

function Update-NavigationButtonsState {
    if ($BtnExplorerBack) {
        $BtnExplorerBack.IsEnabled    = ($Script:ExplorerHistoryIndex -gt 0)
    }
    if ($BtnExplorerForward) {
        $BtnExplorerForward.IsEnabled = ($Script:ExplorerHistoryIndex -lt ($Script:ExplorerHistory.Count - 1))
    }
    if ($BtnExplorerUp) {
        $parent = [System.IO.Path]::GetDirectoryName($Script:ExplorerCurrentPath)
        $BtnExplorerUp.IsEnabled      = (-not [string]::IsNullOrEmpty($parent))
    }
}

function Refresh-ExplorerCurrentDirectory {
    $target = $Script:ExplorerCurrentPath
    if (-not (Test-Path -LiteralPath $target)) { return }

    Reset-LivePreviewPane

    $items = [ZeroExplore.FileExplorerEngine]::GetDirectoryItems($target)
    $Script:ExplorerAllItems = $items

    Apply-ExplorerFilter

    $totalBytes = 0
    $actualCount = 0
    foreach ($it in $items) {
        if (-not $it.IsBanner) {
            $actualCount++
            if (-not $it.IsDirectory) { $totalBytes += $it.SizeBytes }
        }
    }
    $sizeFormatted = [ZeroExplore.FileExplorerEngine]::FormatSize($totalBytes)
    $TxtExplorerStatusCount.Text = "$actualCount items ($sizeFormatted)"
    $TxtExplorerSelectedInfo.Text = ""

    # Cancel any active folder size calculation from previous directory
    if ($Script:FolderSizeCts) {
        try { $Script:FolderSizeCts.Cancel(); $Script:FolderSizeCts.Dispose() } catch {}
        $Script:FolderSizeCts = $null
    }

    # Start non-blocking background folder size calculation for all folders
    $Script:FolderSizeCts = New-Object System.Threading.CancellationTokenSource
    $foldersToCalc = New-Object System.Collections.Generic.List[ZeroExplore.FileItem]
    foreach ($it in $items) {
        if ($it.IsDirectory) { $foldersToCalc.Add($it) }
    }
    if ($foldersToCalc.Count -gt 0) {
        [ZeroExplore.FileExplorerEngine]::CalculateFolderSizesAsync($foldersToCalc, $Script:FolderSizeCts.Token)
    }
}

function Apply-ExplorerFilter {
    $filter = $TxtExplorerFilter.Text.Trim().ToLowerInvariant()
    $displayItems = $null
    if ([string]::IsNullOrWhiteSpace($filter)) {
        $displayItems = $Script:ExplorerAllItems
    } else {
        $filtered = New-Object System.Collections.Generic.List[ZeroExplore.FileItem]
        foreach ($item in $Script:ExplorerAllItems) {
            if ($item.IsBanner) { continue }
            if ($item.Name.ToLowerInvariant().Contains($filter)) {
                $filtered.Add($item)
            }
        }
        $displayItems = $filtered
    }

    # Apply High-Performance C# Sorter across all items
    if ($displayItems -and $displayItems.Count -gt 0) {
        $displayItems = [ZeroExplore.FileExplorerEngine]::SortItems($displayItems, $Script:CurrentSortField, $Script:CurrentSortAscending)
    }

    if ($ExplorerDataGrid) { $ExplorerDataGrid.ItemsSource = $displayItems }
    if ($ExplorerIconGrid) { $ExplorerIconGrid.ItemsSource = $displayItems }

    if ($Script:CurrentViewMode -ne "Details" -and $displayItems) {
        $thumbWidth = if ($Script:CurrentViewMode -eq "LargeIcons") { 180 } else { 120 }
        [ZeroExplore.FileExplorerEngine]::LoadThumbnailsAsync($displayItems, $thumbWidth)
    }
}

# ==============================================================================
# EXPLORER VIEW MODES & SELECTION HELPERS
# ==============================================================================
function Get-ExplorerSelectedItems {
    $items = if ($Script:CurrentViewMode -eq "Details") {
        if ($ExplorerDataGrid) { @($ExplorerDataGrid.SelectedItems) } else { @() }
    } else {
        if ($ExplorerIconGrid) { @($ExplorerIconGrid.SelectedItems) } else { @() }
    }
    return @($items | Where-Object { $_ -and -not $_.IsBanner })
}

function Get-ExplorerSelectedItem {
    $sel = $null
    if ($Script:CurrentViewMode -eq "Details") {
        if ($ExplorerDataGrid) { $sel = $ExplorerDataGrid.SelectedItem }
    } else {
        if ($ExplorerIconGrid) { $sel = $ExplorerIconGrid.SelectedItem }
    }
    if ($sel -and $sel.IsBanner) { return $null }
    return $sel
}

function Select-AllExplorerItems {
    if ($Script:CurrentViewMode -eq "Details") {
        if ($ExplorerDataGrid) { $ExplorerDataGrid.SelectAll() }
    } else {
        if ($ExplorerIconGrid) { $ExplorerIconGrid.SelectAll() }
    }
}

function Set-ExplorerViewMode([string]$mode) {
    if ($mode -ne "Details" -and $mode -ne "MediumIcons" -and $mode -ne "LargeIcons") {
        $mode = "Details"
    }
    $Script:CurrentViewMode = $mode
    $curSel = Get-ExplorerSelectedItem

    if ($mode -eq "Details") {
        if ($TxtViewModeLabel) { $TxtViewModeLabel.Text = "Details" }
        if ($IconViewModeGlyph) { $IconViewModeGlyph.Text = [char]0xE179 }
        if ($ExplorerIconGrid) { $ExplorerIconGrid.Visibility = [System.Windows.Visibility]::Collapsed }
        if ($ExplorerDataGrid) {
            $ExplorerDataGrid.Visibility = [System.Windows.Visibility]::Visible
            if ($curSel) { $ExplorerDataGrid.SelectedItem = $curSel; $ExplorerDataGrid.ScrollIntoView($curSel) }
        }
    } elseif ($mode -eq "MediumIcons") {
        if ($TxtViewModeLabel) { $TxtViewModeLabel.Text = "Medium Icons" }
        if ($IconViewModeGlyph) { $IconViewModeGlyph.Text = [char]0xE8B9 }
        if ($ExplorerIconGrid) {
            $ExplorerIconGrid.ItemTemplate = $Window.Resources["IconGridMediumTemplate"]
            $ExplorerIconGrid.Visibility = [System.Windows.Visibility]::Visible
            if ($curSel) { $ExplorerIconGrid.SelectedItem = $curSel; $ExplorerIconGrid.ScrollIntoView($curSel) }
        }
        if ($ExplorerDataGrid) { $ExplorerDataGrid.Visibility = [System.Windows.Visibility]::Collapsed }
        if ($ExplorerIconGrid -and $ExplorerIconGrid.ItemsSource) {
            [ZeroExplore.FileExplorerEngine]::LoadThumbnailsAsync($ExplorerIconGrid.ItemsSource, 140)
        }
    } elseif ($mode -eq "LargeIcons") {
        if ($TxtViewModeLabel) { $TxtViewModeLabel.Text = "Large Icons" }
        if ($IconViewModeGlyph) { $IconViewModeGlyph.Text = [char]0xEB9F }
        if ($ExplorerIconGrid) {
            $ExplorerIconGrid.ItemTemplate = $Window.Resources["IconGridLargeTemplate"]
            $ExplorerIconGrid.Visibility = [System.Windows.Visibility]::Visible
            if ($curSel) { $ExplorerIconGrid.SelectedItem = $curSel; $ExplorerIconGrid.ScrollIntoView($curSel) }
        }
        if ($ExplorerDataGrid) { $ExplorerDataGrid.Visibility = [System.Windows.Visibility]::Collapsed }
        if ($ExplorerIconGrid -and $ExplorerIconGrid.ItemsSource) {
            [ZeroExplore.FileExplorerEngine]::LoadThumbnailsAsync($ExplorerIconGrid.ItemsSource, 220)
        }
    }

    On-ExplorerSelectionChanged
}

# ==============================================================================
# EXPLORER FILE SORTER ENGINE
# ==============================================================================
function Set-ExplorerSortMode([string]$field = "Name", $ascending = $true) {
    $field = if ($field) { [string]$field } else { "Name" }
    $ascending = if ($null -ne $ascending -and "$ascending" -ne "") { [bool]$ascending } else { $true }
    $Script:CurrentSortField = $field
    $Script:CurrentSortAscending = $ascending

    if ($TxtSortModeLabel) {
        $TxtSortModeLabel.Text = switch ($field) {
            "Date" { "Date" }
            "Size" { "Size" }
            "Type" { "Type" }
            default { "Name" }
        }
    }
    if ($IconSortDirection) {
        $IconSortDirection.Text = if ($ascending) { [char]0xE70E } else { [char]0xE70D } # 0xE70E = Up, 0xE70D = Down
    }

    Apply-ExplorerFilter
}

function Cycle-ExplorerSortMode {
    if ($Script:CurrentSortField -eq "Name" -and $Script:CurrentSortAscending) {
        Set-ExplorerSortMode "Name" $false
    } elseif ($Script:CurrentSortField -eq "Name" -and -not $Script:CurrentSortAscending) {
        Set-ExplorerSortMode "Date" $false # Newest first
    } elseif ($Script:CurrentSortField -eq "Date" -and -not $Script:CurrentSortAscending) {
        Set-ExplorerSortMode "Date" $true  # Oldest first
    } elseif ($Script:CurrentSortField -eq "Date" -and $Script:CurrentSortAscending) {
        Set-ExplorerSortMode "Size" $false # Largest first
    } elseif ($Script:CurrentSortField -eq "Size" -and -not $Script:CurrentSortAscending) {
        Set-ExplorerSortMode "Size" $true  # Smallest first
    } elseif ($Script:CurrentSortField -eq "Size" -and $Script:CurrentSortAscending) {
        Set-ExplorerSortMode "Type" $true
    } else {
        Set-ExplorerSortMode "Name" $true
    }
}

function Cycle-ExplorerViewMode {
    if ($Script:CurrentViewMode -eq "Details") {
        Set-ExplorerViewMode "MediumIcons"
    } elseif ($Script:CurrentViewMode -eq "MediumIcons") {
        Set-ExplorerViewMode "LargeIcons"
    } else {
        Set-ExplorerViewMode "Details"
    }
}

# ==============================================================================
# COPY / CUT / PASTE / DELETE WORKFLOW
# ==============================================================================
function Set-ExplorerClipboard([string]$mode) {
    $selected = Get-ExplorerSelectedItems
    if ($selected.Count -eq 0) {
        $actionVerb = if ($mode -eq "Cut") { "cut" } else { "copy" }
        $TxtTransferStatus.Text = "Please select one or more items to $actionVerb."
        $TxtTransferStatus.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#F87171"))
        return
    }

    $Script:ClipboardItems.Clear()
    $Script:ClipboardMode = $mode

    $strCol = New-Object System.Collections.Specialized.StringCollection
    $itemNames = New-Object System.Collections.Generic.List[string]

    foreach ($item in $selected) {
        if ($item -is [ZeroExplore.FileItem]) {
            $Script:ClipboardItems.Add($item.FullPath)
            $strCol.Add($item.FullPath)
            $itemNames.Add($item.Name)
        }
    }

    try {
        [System.Windows.Clipboard]::SetFileDropList($strCol)
    } catch {}

    $isCut = ($mode -eq "Cut")
    $verb = if ($isCut) { "Currently cutting" } else { "Currently copying" }
    $TxtTransferStatus.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#4ADE80"))

    if ($itemNames.Count -eq 1) {
        $TxtTransferStatus.Text = "${verb}: '$($itemNames[0])' (Ctrl+V to paste)"
    } elseif ($itemNames.Count -gt 1) {
        $TxtTransferStatus.Text = "${verb}: '$($itemNames[0])' + $($itemNames.Count - 1) other item(s) (Ctrl+V to paste)"
    } else {
        $TxtTransferStatus.Text = ""
    }

    Update-PasteButtonUI
}

function Update-PasteButtonUI {
    $count = $Script:ClipboardItems.Count
    if ($count -eq 0) {
        try {
            if ([System.Windows.Clipboard]::ContainsFileDropList()) {
                $dropList = [System.Windows.Clipboard]::GetFileDropList()
                $count = $dropList.Count
            }
        } catch {}
    }

    if ($count -gt 0) {
        if ($BadgePasteStatus) { $BadgePasteStatus.Visibility = "Visible" }
        if ($TxtPasteBadge) {
            $modeLabel = if ($Script:ClipboardMode -eq "Cut") { "Cut" } else { "Copy" }
            $TxtPasteBadge.Text = "$count $modeLabel"
        }
    } else {
        if ($BadgePasteStatus) { $BadgePasteStatus.Visibility = "Collapsed" }
    }
}

function Execute-ExplorerPaste {
    Show-ExplorerFilesView
    $targetDir = $Script:ExplorerCurrentPath
    if (-not (Test-Path -LiteralPath $targetDir)) {
        $TxtTransferStatus.Text = "Destination directory does not exist: $targetDir"
        $TxtTransferStatus.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#F87171"))
        return
    }

    $pathsToPaste = New-Object System.Collections.Generic.List[string]
    if ($Script:ClipboardItems.Count -gt 0) {
        foreach ($p in $Script:ClipboardItems) { $pathsToPaste.Add($p) }
    } else {
        try {
            if ([System.Windows.Clipboard]::ContainsFileDropList()) {
                $dropList = [System.Windows.Clipboard]::GetFileDropList()
                foreach ($p in $dropList) { $pathsToPaste.Add($p) }
            }
        } catch {}
    }

    if ($pathsToPaste.Count -eq 0) {
        $TxtTransferStatus.Text = "Clipboard is empty. Select files and click Copy or Cut first."
        $TxtTransferStatus.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#F87171"))
        return
    }

    $isCut = ($Script:ClipboardMode -eq "Cut")
    $actionWord = if ($isCut) { "Moving" } else { "Copying" }
    $currentActionVerb = if ($isCut) { "Currently cutting" } else { "Currently copying" }
    $actionIcon = if ($isCut) { [char]0xE8C6 } else { [char]0xE896 }

    $firstItemName = if ($pathsToPaste.Count -gt 0) { [System.IO.Path]::GetFileName($pathsToPaste[0]) } else { "" }
    $statusNameText = if ($pathsToPaste.Count -eq 1) { "'$firstItemName'" } else { "'$firstItemName' + $($pathsToPaste.Count - 1) more" }

    # Show Progress UI
    if ($PanelTransferProgress) {
        $PanelTransferProgress.Visibility = "Visible"
        if ($IconTransferProgress) { $IconTransferProgress.Text = $actionIcon }
        if ($TxtTransferAction)    { $TxtTransferAction.Text = "${actionWord}: $statusNameText" }
        if ($ProgBarTransfer)      { $ProgBarTransfer.Value = 0 }
        if ($TxtTransferPercent)   { $TxtTransferPercent.Text = "0%" }
    }
    $TxtTransferStatus.Text = "${currentActionVerb}: $statusNameText..."
    $TxtTransferStatus.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#c15f3c"))

    # Launch background copy task directly in C#
    [ZeroExplore.FileExplorerEngine]::StartPasteAsync($pathsToPaste, $targetDir, $isCut)

    # UI Poll Timer on the WPF Dispatcher Thread
    $transferTimer = New-Object System.Windows.Threading.DispatcherTimer
    $transferTimer.Interval = [TimeSpan]::FromMilliseconds(30)
    $transferTimer.add_Tick({
        param($s, $e)
        $pct = [ZeroExplore.FileExplorerEngine]::TransferProgress
        $curFile = [ZeroExplore.FileExplorerEngine]::TransferCurrentFile
        $isDone = [ZeroExplore.FileExplorerEngine]::TransferIsFinished

        if ($ProgBarTransfer)    { $ProgBarTransfer.Value = $pct }
        if ($TxtTransferPercent) { $TxtTransferPercent.Text = "$([Math]::Round($pct))%" }
        if ($TxtTransferAction -and $curFile -and $curFile -ne "Complete") {
            $shortName = if ($curFile.Length -gt 22) { $curFile.Substring(0, 19) + "..." } else { $curFile }
            $TxtTransferAction.Text = "${actionWord}: $shortName"
            if ($TxtTransferStatus) {
                $TxtTransferStatus.Text = "${currentActionVerb}: '$shortName' ($([Math]::Round($pct))%)"
            }
        }

        if ($isDone) {
            $s.Stop()
            $cnt = [ZeroExplore.FileExplorerEngine]::TransferCount
            $el  = [ZeroExplore.FileExplorerEngine]::TransferElapsedSeconds
            $resWord = if ($isCut) { "Moved" } else { "Copied" }

            if ($ProgBarTransfer)    { $ProgBarTransfer.Value = 100 }
            if ($TxtTransferPercent) { $TxtTransferPercent.Text = "100%" }
            if ($TxtTransferAction)  { $TxtTransferAction.Text = "Finished" }

            $TxtTransferStatus.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#4ADE80"))
            if ($cnt -eq 1 -and $firstItemName) {
                $TxtTransferStatus.Text = "Successfully $resWord '$firstItemName' (${el}s)."
            } else {
                $TxtTransferStatus.Text = "Successfully $resWord $cnt item(s) (${el}s)."
            }

            # Keep visible for 2.5 seconds then collapse
            $dismissTimer = New-Object System.Windows.Threading.DispatcherTimer
            $dismissTimer.Interval = [TimeSpan]::FromSeconds(2.5)
            $dismissTimer.add_Tick({
                param($dt, $dte)
                if ($PanelTransferProgress) { $PanelTransferProgress.Visibility = "Collapsed" }
                $dt.Stop()
            })
            $dismissTimer.Start()

            if ($isCut) {
                $Script:ClipboardItems.Clear()
                try { [System.Windows.Clipboard]::Clear() } catch {}
                Update-PasteButtonUI
            }
            Refresh-ExplorerCurrentDirectory
        }
    }.GetNewClosure())
    $transferTimer.Start()
}

function Delete-SelectedItems {
    $selected = Get-ExplorerSelectedItems
    if ($selected.Count -eq 0) { return }

    $msg = if ($selected.Count -eq 1) {
        "Are you sure you want to delete '$($selected[0].Name)'?"
    } else {
        "Are you sure you want to delete these $($selected.Count) items?"
    }

    $res = [System.Windows.MessageBox]::Show($msg, "ZeroExplore - Confirm Delete", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
    if ($res -eq [System.Windows.MessageBoxResult]::Yes) {
        $deletedCount = 0
        foreach ($it in $selected) {
            try {
                if ($it.IsDirectory) {
                    [System.IO.Directory]::Delete($it.FullPath, $true)
                } else {
                    [System.IO.File]::Delete($it.FullPath)
                }
                $deletedCount++
            } catch {}
        }
        Refresh-ExplorerCurrentDirectory
        $TxtTransferStatus.Text = "Deleted $deletedCount item(s)."
    }
}

# ==============================================================================
# LIVE PREVIEW INSPECTOR ENGINE
# ==============================================================================
function Reset-LivePreviewPane {
    try {
        if ($mediaTimer) { $mediaTimer.Stop() }
        if ($PreviewMediaElement) {
            $PreviewMediaElement.Stop()
            $PreviewMediaElement.Source = $null
        }
        $PreviewImgControl.Source = $null
        if ($TxtPreviewContent) {
            $TxtPreviewContent.Document.Blocks.Clear()
            $TxtPreviewContent.IsReadOnly = $true
        }
        if ($PanelEditActions)   { $PanelEditActions.Visibility = "Collapsed" }
        if ($BtnEditTextPreview) { $BtnEditTextPreview.Visibility = "Visible" }
        if ($PanelMediaFailed)   { $PanelMediaFailed.Visibility = "Collapsed" }
        if ($PanelAudioDisplay)  { $PanelAudioDisplay.Visibility = "Collapsed" }
        if ($OverlayPlayButton)  { $OverlayPlayButton.Visibility = "Collapsed" }
        $Script:IsMediaPlaying = $false
        if ($TxtMediaPlayIcon)   { $TxtMediaPlayIcon.Text = [char]0xE768 }
    } catch {}

    $TxtPreviewFileName.Text = "No Selection"
    $TxtPreviewMetaDetails.Text = "Select a file to inspect metadata and content"

    if ($PanelPreviewEmpty)  { $PanelPreviewEmpty.Visibility  = "Visible" }
    if ($PanelPreviewImage)  { $PanelPreviewImage.Visibility  = "Collapsed" }
    if ($PanelPreviewVideo)  { $PanelPreviewVideo.Visibility  = "Collapsed" }
    if ($PanelPreviewText)   { $PanelPreviewText.Visibility   = "Collapsed" }
    if ($PanelPreviewBinary) { $PanelPreviewBinary.Visibility = "Collapsed" }
    if ($PanelPreviewFolder) { $PanelPreviewFolder.Visibility = "Collapsed" }
}

function Update-LivePreviewPane([ZeroExplore.FileItem]$item) {
    if (-not $item -or [string]::IsNullOrEmpty($item.FullPath) -or (-not (Test-Path -LiteralPath $item.FullPath))) {
        Reset-LivePreviewPane
        return
    }

    try {
        $mediaTimer.Stop()
        $PreviewMediaElement.Stop()
        $PreviewMediaElement.Source = $null
        $PreviewImgControl.Source = $null
    } catch {}

    $TxtPreviewFileName.Text = $item.Name
    $TxtPreviewMetaDetails.Text = "$($item.ItemType)  |  $($item.SizeFormatted)  |  $($item.DateModifiedFormatted)"

    if ($item.IsDirectory) {
        if ($PanelPreviewEmpty)  { $PanelPreviewEmpty.Visibility  = "Collapsed" }
        if ($PanelPreviewImage)  { $PanelPreviewImage.Visibility  = "Collapsed" }
        if ($PanelPreviewVideo)  { $PanelPreviewVideo.Visibility  = "Collapsed" }
        if ($PanelPreviewText)   { $PanelPreviewText.Visibility   = "Collapsed" }
        if ($PanelPreviewBinary) { $PanelPreviewBinary.Visibility = "Collapsed" }
        if ($PanelPreviewFolder) { $PanelPreviewFolder.Visibility = "Visible" }
        if ($ImgFolderPreviewIcon -and [ZeroExplore.FileExplorerEngine]::FolderIcon) {
            $ImgFolderPreviewIcon.Source = [ZeroExplore.FileExplorerEngine]::FolderIcon
        }
        if ($TxtFolderTitle)    { $TxtFolderTitle.Text = $item.Name }
        $dispFolderSize = if ($item.SizeBytes -gt 0) { $item.SizeFormatted } else { "Calculating..." }
        if ($TxtFolderSize)     { $TxtFolderSize.Text = "Size: $dispFolderSize" }
        if ($TxtFolderModified) { $TxtFolderModified.Text = "Modified: $($item.DateModifiedFormatted)" }
        return
    }

    $ext = if ($item.Extension) { $item.Extension.ToLowerInvariant() } else { "" }
    $fullPath = $item.FullPath

    # 1. Images
    if ($ext -in @(".png", ".jpg", ".jpeg", ".bmp", ".gif", ".ico", ".webp", ".tif", ".tiff", ".jfif")) {
        try {
            $bi = New-Object System.Windows.Media.Imaging.BitmapImage
            $bi.BeginInit()
            $bi.UriSource = New-Object System.Uri($fullPath, [System.UriKind]::Absolute)
            $bi.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
            $bi.EndInit()

            $PreviewImgControl.Source = $bi
            $TxtPreviewMetaDetails.Text = "$($bi.PixelWidth) x $($bi.PixelHeight) px  |  $($item.SizeFormatted)"

            if ($PanelPreviewEmpty)  { $PanelPreviewEmpty.Visibility  = "Collapsed" }
            if ($PanelPreviewImage)  { $PanelPreviewImage.Visibility  = "Visible" }
            if ($PanelPreviewVideo)  { $PanelPreviewVideo.Visibility  = "Collapsed" }
            if ($PanelPreviewText)   { $PanelPreviewText.Visibility   = "Collapsed" }
            if ($PanelPreviewBinary) { $PanelPreviewBinary.Visibility = "Collapsed" }
            if ($PanelPreviewFolder) { $PanelPreviewFolder.Visibility = "Collapsed" }
            return
        } catch {}
    }

    # 2. Audio & Video (Studio Player with Instant Non-Locking Playback)
    if ($ext -in @(".mp4", ".mkv", ".avi", ".mov", ".wmv", ".webm", ".m4v", ".3gp", ".flv", ".mp3", ".wav", ".flac", ".m4a", ".aac", ".ogg", ".wma")) {
        try {
            $Script:CurrentMediaFilePath = $fullPath
            if ($PanelMediaFailed)  { $PanelMediaFailed.Visibility = "Collapsed" }
            if ($PanelAudioDisplay) { $PanelAudioDisplay.Visibility = "Collapsed" }
            if ($OverlayPlayButton) { $OverlayPlayButton.Visibility = "Collapsed" }

            $isAudioOnly = ($ext -in @(".mp3", ".wav", ".flac", ".m4a", ".aac", ".ogg", ".wma"))
            if ($isAudioOnly) {
                if ($PanelAudioDisplay) {
                    $PanelAudioDisplay.Visibility = "Visible"
                    if ($TxtAudioTitle) { $TxtAudioTitle.Text = $item.Name }
                    if ($TxtAudioSub)   { $TxtAudioSub.Text = "$($item.ItemType)  •  $($item.SizeFormatted)" }
                }
            }

            $Script:PendingMediaSeekSeconds = $null
            $Script:LastSeekSeconds = $null
            $Script:LastSeekTime = $null

            $PreviewMediaElement.Source = New-Object System.Uri($fullPath, [System.UriKind]::Absolute)
            $PreviewMediaElement.Volume = $SliderMediaVolume.Value
            
            # Start playing immediately on selection
            $PreviewMediaElement.Play()
            $Script:IsMediaPlaying = $true
            if ($TxtMediaPlayIcon)  { $TxtMediaPlayIcon.Text = [char]0xE769 } # Pause glyph
            if ($OverlayPlayButton) { $OverlayPlayButton.Visibility = "Collapsed" }
            $mediaTimer.Start()

            $SliderMediaTimeline.Value = 0
            if ($TxtMediaTime) { $TxtMediaTime.Text = "00:00 / --:--" }

            if ($PanelPreviewEmpty)  { $PanelPreviewEmpty.Visibility  = "Collapsed" }
            if ($PanelPreviewImage)  { $PanelPreviewImage.Visibility  = "Collapsed" }
            if ($PanelPreviewVideo)  { $PanelPreviewVideo.Visibility  = "Visible" }
            if ($PanelPreviewText)   { $PanelPreviewText.Visibility   = "Collapsed" }
            if ($PanelPreviewBinary) { $PanelPreviewBinary.Visibility = "Collapsed" }
            if ($PanelPreviewFolder) { $PanelPreviewFolder.Visibility = "Collapsed" }
            return
        } catch {
            if ($PanelMediaFailed) { $PanelMediaFailed.Visibility = "Visible" }
        }
    }

    # 3. Text & Code Documents (Fast Universal C# Engine & Live Editable)
    $textSample = ""
    $lineCount = 0
    if ([ZeroExplore.FileExplorerEngine]::TryReadTextPreview($fullPath, [ref]$textSample, [ref]$lineCount)) {
        $Script:CurrentPreviewFilePath = $fullPath
        $lang = [ZeroExplore.FileExplorerEngine]::GetLanguageName($ext)
        if ($TxtCodeLanguage)  { $TxtCodeLanguage.Text  = $lang }
        if ($TxtCodeLineCount) { $TxtCodeLineCount.Text = "$lineCount lines  |  $($item.SizeFormatted)" }
        $doc = [ZeroExplore.SyntaxEngine]::BuildDocument($textSample, $lang)
        $TxtPreviewContent.Document = $doc
        $TxtPreviewContent.IsReadOnly = $true
        if ($PanelEditActions)   { $PanelEditActions.Visibility = "Collapsed" }
        if ($BtnEditTextPreview) { $BtnEditTextPreview.Visibility = "Visible" }

        if ($PanelPreviewEmpty)  { $PanelPreviewEmpty.Visibility  = "Collapsed" }
        if ($PanelPreviewImage)  { $PanelPreviewImage.Visibility  = "Collapsed" }
        if ($PanelPreviewVideo)  { $PanelPreviewVideo.Visibility  = "Collapsed" }
        if ($PanelPreviewText)   { $PanelPreviewText.Visibility   = "Visible" }
        if ($PanelPreviewBinary) { $PanelPreviewBinary.Visibility = "Collapsed" }
        if ($PanelPreviewFolder) { $PanelPreviewFolder.Visibility = "Collapsed" }
        return
    }

    # 4. Binary / Compiled File Fallback
    if ($PanelPreviewEmpty)  { $PanelPreviewEmpty.Visibility  = "Collapsed" }
    if ($PanelPreviewImage)  { $PanelPreviewImage.Visibility  = "Collapsed" }
    if ($PanelPreviewVideo)  { $PanelPreviewVideo.Visibility  = "Collapsed" }
    if ($PanelPreviewText)   { $PanelPreviewText.Visibility   = "Collapsed" }
    if ($PanelPreviewBinary) { $PanelPreviewBinary.Visibility = "Visible" }
    if ($PanelPreviewFolder) { $PanelPreviewFolder.Visibility = "Collapsed" }

    if ($TxtBinaryTitle) { $TxtBinaryTitle.Text = $item.Name }
    if ($TxtBinaryType)  { $TxtBinaryType.Text  = "Type: $($item.ItemType)" }
    if ($TxtBinarySize)  { $TxtBinarySize.Text  = "Size: $($item.SizeFormatted) ($($item.SizeBytes) bytes)" }
    if ($TxtBinaryDate)  { $TxtBinaryDate.Text  = "Modified: $($item.DateModifiedFormatted)" }
}

function Execute-CreateNewFolder {
    Show-ExplorerFilesView
    $current = $Script:ExplorerCurrentPath
    $baseName = "New Folder"
    $newDir = Join-Path $current $baseName
    $count = 2
    while (Test-Path -LiteralPath $newDir) {
        $newDir = Join-Path $current "$baseName ($count)"
        $count++
    }
    try {
        [System.IO.Directory]::CreateDirectory($newDir) | Out-Null
        Refresh-ExplorerCurrentDirectory
        $TxtTransferStatus.Text = "Created folder: $([System.IO.Path]::GetFileName($newDir))"
    } catch {
        [System.Windows.MessageBox]::Show("Failed to create folder:`n$_", "ZeroExplore Error", "OK", "Error")
    }
}

# Create New File Helper
function Execute-CreateNewFile {
    Show-ExplorerFilesView
    $current = $Script:ExplorerCurrentPath
    $baseName = "New Document.txt"
    $newFile = Join-Path $current $baseName
    $count = 2
    while (Test-Path -LiteralPath $newFile) {
        $newFile = Join-Path $current "New Document ($count).txt"
        $count++
    }
    try {
        [System.IO.File]::WriteAllText($newFile, "")
        Refresh-ExplorerCurrentDirectory
        $TxtTransferStatus.Text = "Created file: $([System.IO.Path]::GetFileName($newFile))"
    } catch {
        [System.Windows.MessageBox]::Show("Failed to create file:`n$_", "ZeroExplore Error", "OK", "Error")
    }
}

$BtnNewFolder.add_Click({ Execute-CreateNewFolder })
$BtnNewFile.add_Click({ Execute-CreateNewFile })
if ($BtnCopy)  { $BtnCopy.add_Click({ Set-ExplorerClipboard "Copy" }) }
if ($BtnCut)   { $BtnCut.add_Click({ Set-ExplorerClipboard "Cut" }) }
if ($BtnPaste) { $BtnPaste.add_Click({ Execute-ExplorerPaste }) }

$BtnToolbarRename = $Window.FindName("BtnToolbarRename")
if ($BtnToolbarRename) { $BtnToolbarRename.add_Click({ Show-ExplorerRenameDialog }) }

$BtnToolbarDelete = $Window.FindName("BtnToolbarDelete")
if ($BtnToolbarDelete) { $BtnToolbarDelete.add_Click({ Delete-SelectedItems }) }




# ==============================================================================
# PREVIEW PANE MANAGEMENT & DEBOUNCED SELECTION
# ==============================================================================
$Script:IsPreviewPaneOpen = $true
$Script:PendingPreviewItem = $null
$Script:FolderSizeCts = $null
$Script:CurrentPreviewFilePath = ""

function Enter-PreviewEditMode {
    if (-not $Script:CurrentPreviewFilePath -or -not (Test-Path -LiteralPath $Script:CurrentPreviewFilePath)) { return }
    if ($TxtPreviewContent) {
        $TxtPreviewContent.IsReadOnly = $false
        $TxtPreviewContent.Focus() | Out-Null
    }
    if ($BtnEditTextPreview) { $BtnEditTextPreview.Visibility = "Collapsed" }
    if ($PanelEditActions)   { $PanelEditActions.Visibility = "Visible" }
}

function Exit-PreviewEditMode([bool]$revert = $false) {
    if ($revert -and $Script:CurrentPreviewFilePath -and (Test-Path -LiteralPath $Script:CurrentPreviewFilePath)) {
        try {
            $reloaded = [System.IO.File]::ReadAllText($Script:CurrentPreviewFilePath, [System.Text.Encoding]::UTF8)
            $ext = [System.IO.Path]::GetExtension($Script:CurrentPreviewFilePath)
            $lang = [ZeroExplore.FileExplorerEngine]::GetLanguageName($ext)
            $TxtPreviewContent.Document = [ZeroExplore.SyntaxEngine]::BuildDocument($reloaded, $lang)
        } catch {}
    }
    if ($TxtPreviewContent)  { $TxtPreviewContent.IsReadOnly = $true }
    if ($PanelEditActions)   { $PanelEditActions.Visibility = "Collapsed" }
    if ($BtnEditTextPreview) { $BtnEditTextPreview.Visibility = "Visible" }
}

function Save-PreviewTextContent {
    if (-not $Script:CurrentPreviewFilePath -or -not (Test-Path -LiteralPath $Script:CurrentPreviewFilePath)) { return }
    try {
        $contentToSave = [ZeroExplore.SyntaxEngine]::ExtractText($TxtPreviewContent.Document)
        [System.IO.File]::WriteAllText($Script:CurrentPreviewFilePath, $contentToSave, [System.Text.Encoding]::UTF8)
        
        # Re-highlight document with coding colors
        $ext = [System.IO.Path]::GetExtension($Script:CurrentPreviewFilePath)
        $lang = [ZeroExplore.FileExplorerEngine]::GetLanguageName($ext)
        $TxtPreviewContent.Document = [ZeroExplore.SyntaxEngine]::BuildDocument($contentToSave, $lang)

        $fileName = [System.IO.Path]::GetFileName($Script:CurrentPreviewFilePath)
        if ($TxtTransferStatus) {
            $TxtTransferStatus.Text = "Saved changes to '$fileName' successfully."
            $TxtTransferStatus.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#4ADE80"))
        }
        Exit-PreviewEditMode $false
        Refresh-ExplorerCurrentDirectory
    } catch {
        [System.Windows.MessageBox]::Show("Failed to save file:`n$($_.Exception.Message)", "ZeroExplore - Save Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    }
}

function Update-ResponsiveExplorerColumns([double]$width) {
    if (-not $ExplorerDataGrid -or $ExplorerDataGrid.Columns.Count -lt 4) { return }
    $colName = $ExplorerDataGrid.Columns[0]
    $colSize = $ExplorerDataGrid.Columns[1]
    $colType = $ExplorerDataGrid.Columns[2]
    $colDate = $ExplorerDataGrid.Columns[3]

    if ($width -gt 0 -and $width -lt 280) {
        # Extreme narrow: Show ONLY file name, collapse size, type, and date
        if ($colDate.Visibility -ne [System.Windows.Visibility]::Collapsed) { $colDate.Visibility = [System.Windows.Visibility]::Collapsed }
        if ($colType.Visibility -ne [System.Windows.Visibility]::Collapsed) { $colType.Visibility = [System.Windows.Visibility]::Collapsed }
        if ($colSize.Visibility -ne [System.Windows.Visibility]::Collapsed) { $colSize.Visibility = [System.Windows.Visibility]::Collapsed }
    } elseif ($width -ge 280 -and $width -lt 420) {
        # Narrow: Show file name and size, collapse type and date
        if ($colDate.Visibility -ne [System.Windows.Visibility]::Collapsed) { $colDate.Visibility = [System.Windows.Visibility]::Collapsed }
        if ($colType.Visibility -ne [System.Windows.Visibility]::Collapsed) { $colType.Visibility = [System.Windows.Visibility]::Collapsed }
        if ($colSize.Visibility -ne [System.Windows.Visibility]::Visible)   { $colSize.Visibility = [System.Windows.Visibility]::Visible }
    } elseif ($width -ge 420 -and $width -lt 560) {
        # Compact: Show file name, size, and type; collapse date modified
        if ($colDate.Visibility -ne [System.Windows.Visibility]::Collapsed) { $colDate.Visibility = [System.Windows.Visibility]::Collapsed }
        if ($colType.Visibility -ne [System.Windows.Visibility]::Visible)   { $colType.Visibility = [System.Windows.Visibility]::Visible }
        if ($colSize.Visibility -ne [System.Windows.Visibility]::Visible)   { $colSize.Visibility = [System.Windows.Visibility]::Visible }
    } elseif ($width -ge 560) {
        # Wide: Show all columns
        if ($colDate.Visibility -ne [System.Windows.Visibility]::Visible)   { $colDate.Visibility = [System.Windows.Visibility]::Visible }
        if ($colType.Visibility -ne [System.Windows.Visibility]::Visible)   { $colType.Visibility = [System.Windows.Visibility]::Visible }
        if ($colSize.Visibility -ne [System.Windows.Visibility]::Visible)   { $colSize.Visibility = [System.Windows.Visibility]::Visible }
    }
}

function Show-PreviewPane {
    $Script:IsPreviewPaneOpen = $true
    if ($ColPreviewPane) {
        $ColPreviewPane.MinWidth = 100
        $restoreWidth = if ($Script:SavedPreviewPaneWidth -and $Script:SavedPreviewPaneWidth -gt 120) { $Script:SavedPreviewPaneWidth } else { 380 }
        $ColPreviewPane.Width = [System.Windows.GridLength]::new($restoreWidth)
    }
    if ($ColSplitterPreview) {
        $ColSplitterPreview.Width = [System.Windows.GridLength]::Auto
    }
    if ($TxtBadgePreviewStatus) { $TxtBadgePreviewStatus.Text = "ON" }
    # Refresh preview for currently selected item
    $selectedList = $ExplorerDataGrid.SelectedItems
    if ($selectedList.Count -eq 1 -and ($selectedList[0] -is [ZeroExplore.FileItem])) {
        Update-LivePreviewPane $selectedList[0]
    }
    if ($ExplorerDataGrid) { Update-ResponsiveExplorerColumns $ExplorerDataGrid.ActualWidth }
}

function Hide-PreviewPane {
    $Script:IsPreviewPaneOpen = $false
    if ($ColPreviewPane -and $ColPreviewPane.ActualWidth -gt 100) {
        $Script:SavedPreviewPaneWidth = $ColPreviewPane.ActualWidth
    }
    Reset-LivePreviewPane
    if ($ColPreviewPane) {
        $ColPreviewPane.MinWidth = 0
        $ColPreviewPane.Width = [System.Windows.GridLength]::new(0)
    }
    if ($ColSplitterPreview) {
        $ColSplitterPreview.Width = [System.Windows.GridLength]::new(0)
    }
    if ($TxtBadgePreviewStatus) { $TxtBadgePreviewStatus.Text = "OFF" }
    if ($ExplorerDataGrid) { Update-ResponsiveExplorerColumns $ExplorerDataGrid.ActualWidth }
}

function Toggle-PreviewPane {
    if ($Script:IsPreviewPaneOpen) {
        Hide-PreviewPane
    } else {
        Show-PreviewPane
    }
}

# ==============================================================================
# STUDIO MEDIA PLAYER ENGINE & EVENT HANDLERS
# ==============================================================================
function Toggle-MediaPlayPause {
    if (-not $PreviewMediaElement -or -not $PreviewMediaElement.Source) { return }
    if ($Script:IsMediaPlaying) {
        $PreviewMediaElement.Pause()
        $Script:IsMediaPlaying = $false
        if ($TxtMediaPlayIcon)  { $TxtMediaPlayIcon.Text = [char]0xE768 } # Play glyph
        if ($OverlayPlayButton) { $OverlayPlayButton.Visibility = "Visible" }
        if ($mediaTimer) { $mediaTimer.Stop() }
    } else {
        $PreviewMediaElement.Play()
        $Script:IsMediaPlaying = $true
        if ($TxtMediaPlayIcon)  { $TxtMediaPlayIcon.Text = [char]0xE769 } # Pause glyph
        if ($OverlayPlayButton) { $OverlayPlayButton.Visibility = "Collapsed" }
        if ($mediaTimer) { $mediaTimer.Start() }
    }
}

function Stop-MediaPlayer {
    if (-not $PreviewMediaElement) { return }
    $PreviewMediaElement.Stop()
    $PreviewMediaElement.Position = [System.TimeSpan]::Zero
    $Script:IsMediaPlaying = $false
    if ($TxtMediaPlayIcon)  { $TxtMediaPlayIcon.Text = [char]0xE768 }
    if ($OverlayPlayButton) { $OverlayPlayButton.Visibility = "Visible" }
    if ($SliderMediaTimeline) { $SliderMediaTimeline.Value = 0 }
    if ($mediaTimer) { $mediaTimer.Stop() }
    if ($TxtMediaTime) {
        $durStr = if ($PreviewMediaElement.NaturalDuration.HasTimeSpan) { "{0:mm\:ss}" -f $PreviewMediaElement.NaturalDuration.TimeSpan } else { "00:00" }
        $TxtMediaTime.Text = "00:00 / $durStr"
    }
}

function Seek-MediaToSeconds([double]$targetSec) {
    if (-not $PreviewMediaElement -or -not $PreviewMediaElement.Source) { return }
    if ($targetSec -lt 0) { $targetSec = 0 }

    # If media is still opening, store pending seek to execute immediately on MediaOpened
    if (-not $PreviewMediaElement.NaturalDuration.HasTimeSpan) {
        $Script:PendingMediaSeekSeconds = $targetSec
        if ($SliderMediaTimeline) { $SliderMediaTimeline.Value = $targetSec }
        return
    }

    $maxSec = $PreviewMediaElement.NaturalDuration.TimeSpan.TotalSeconds
    if ($targetSec -gt $maxSec) { $targetSec = $maxSec }

    $Script:LastSeekSeconds = $targetSec
    $Script:LastSeekTime = [System.DateTime]::UtcNow
    $newPos = [System.TimeSpan]::FromSeconds($targetSec)

    $PreviewMediaElement.Position = $newPos

    if ($SliderMediaTimeline) { $SliderMediaTimeline.Value = $targetSec }
    if ($TxtMediaTime) {
        $curStr = "{0:mm\:ss}" -f $newPos
        $durStr = "{0:mm\:ss}" -f $PreviewMediaElement.NaturalDuration.TimeSpan
        $TxtMediaTime.Text = "$curStr / $durStr"
    }
}

function Seek-MediaDelta([double]$seconds) {
    if (-not $PreviewMediaElement -or -not $PreviewMediaElement.Source) { return }
    $curSec = if ($SliderMediaTimeline -and $SliderMediaTimeline.Value -gt 0) {
        $SliderMediaTimeline.Value
    } else {
        $PreviewMediaElement.Position.TotalSeconds
    }
    Seek-MediaToSeconds ($curSec + $seconds)
}

function Toggle-MediaMute {
    if (-not $SliderMediaVolume) { return }
    if ($SliderMediaVolume.Value -gt 0) {
        $Script:SavedMediaVolume = $SliderMediaVolume.Value
        $SliderMediaVolume.Value = 0
        if ($PreviewMediaElement) { $PreviewMediaElement.Volume = 0 }
        if ($TxtMediaMuteIcon) {
            $TxtMediaMuteIcon.Text = [char]0xE74F # Muted glyph
            $TxtMediaMuteIcon.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#F87171"))
        }
    } else {
        $vol = if ($Script:SavedMediaVolume -gt 0) { $Script:SavedMediaVolume } else { 0.75 }
        $SliderMediaVolume.Value = $vol
        if ($PreviewMediaElement) { $PreviewMediaElement.Volume = $vol }
        if ($TxtMediaMuteIcon) {
            $TxtMediaMuteIcon.Text = [char]0xE767 # Volume glyph
            $TxtMediaMuteIcon.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#A1A1AA"))
        }
    }
}

function Open-CurrentMediaInExternalPlayer {
    if ($Script:CurrentMediaFilePath -and (Test-Path -LiteralPath $Script:CurrentMediaFilePath)) {
        try {
            [System.Diagnostics.Process]::Start((New-Object System.Diagnostics.ProcessStartInfo($Script:CurrentMediaFilePath) -Property @{ UseShellExecute = $true })) | Out-Null
        } catch {
            try { Start-Process $Script:CurrentMediaFilePath } catch {}
        }
    }
}

# Wire MediaElement Lifecycle Events
if ($PreviewMediaElement) {
    $PreviewMediaElement.add_MediaOpened({
        if ($PreviewMediaElement.NaturalDuration.HasTimeSpan) {
            $dur = $PreviewMediaElement.NaturalDuration.TimeSpan
            if ($SliderMediaTimeline) {
                $SliderMediaTimeline.Maximum = $dur.TotalSeconds
            }
            $durStr = "{0:mm\:ss}" -f $dur
            if ($TxtMediaTime) { $TxtMediaTime.Text = "00:00 / $durStr" }

            $w = $PreviewMediaElement.NaturalVideoWidth
            $h = $PreviewMediaElement.NaturalVideoHeight
            if ($w -gt 0 -and $h -gt 0) {
                $sizeStr = if ($Script:PendingPreviewItem) { $Script:PendingPreviewItem.SizeFormatted } else { "" }
                $TxtPreviewMetaDetails.Text = "$w x $h px  |  $sizeStr  |  $durStr"
                if ($PanelAudioDisplay) { $PanelAudioDisplay.Visibility = "Collapsed" }
            } else {
                if ($PanelAudioDisplay) { $PanelAudioDisplay.Visibility = "Visible" }
            }

            # If the user clicked to skip while video was still opening, seek immediately now!
            if ($Script:PendingMediaSeekSeconds -ne $null -and $Script:PendingMediaSeekSeconds -gt 0) {
                $target = $Script:PendingMediaSeekSeconds
                $Script:PendingMediaSeekSeconds = $null
                Seek-MediaToSeconds $target
            }
        }
        if ($PanelMediaFailed) { $PanelMediaFailed.Visibility = "Collapsed" }
    })

    $PreviewMediaElement.add_MediaFailed({
        param($s, $e)
        if ($mediaTimer) { $mediaTimer.Stop() }
        $Script:IsMediaPlaying = $false
        if ($TxtMediaPlayIcon)  { $TxtMediaPlayIcon.Text = [char]0xE768 }
        if ($PanelMediaFailed)  { $PanelMediaFailed.Visibility = "Visible" }
        if ($OverlayPlayButton) { $OverlayPlayButton.Visibility = "Collapsed" }
    })

    $PreviewMediaElement.add_MediaEnded({
        $PreviewMediaElement.Stop()
        $PreviewMediaElement.Position = [System.TimeSpan]::Zero
        $Script:IsMediaPlaying = $false
        if ($TxtMediaPlayIcon)  { $TxtMediaPlayIcon.Text = [char]0xE768 }
        if ($OverlayPlayButton) { $OverlayPlayButton.Visibility = "Visible" }
        if ($SliderMediaTimeline) { $SliderMediaTimeline.Value = 0 }
        if ($mediaTimer) { $mediaTimer.Stop() }
    })
}

# Video Viewport Click -> Toggle Play/Pause
if ($BorderVideoContainer) {
    $BorderVideoContainer.add_MouseLeftButtonUp({
        Toggle-MediaPlayPause
    })
}

# Media Player Buttons
if ($BtnMediaPlayPause)    { $BtnMediaPlayPause.add_Click({ Toggle-MediaPlayPause }) }
if ($BtnMediaStop)         { $BtnMediaStop.add_Click({ Stop-MediaPlayer }) }
if ($BtnMediaRewind)       { $BtnMediaRewind.add_Click({ Seek-MediaDelta -5 }) }
if ($BtnMediaForward)      { $BtnMediaForward.add_Click({ Seek-MediaDelta 5 }) }
if ($BtnMediaMute)         { $BtnMediaMute.add_Click({ Toggle-MediaMute }) }
if ($BtnMediaOpenExternal) { $BtnMediaOpenExternal.add_Click({ Open-CurrentMediaInExternalPlayer }) }
if ($BtnMediaFailedOpen)   { $BtnMediaFailedOpen.add_Click({ Open-CurrentMediaInExternalPlayer }) }

# Timeline Slider Direct Click-to-Point & Smooth Scrubbing
if ($SliderMediaTimeline) {
    # Left click down: mark dragging state so timer doesn't interfere while user clicks/scrubs
    $SliderMediaTimeline.add_PreviewMouseLeftButtonDown({
        param($s, $e)
        $Script:IsUserDraggingSlider = $true
    })

    # Dragging / scrubbing: update time text smoothly in real time
    $SliderMediaTimeline.add_PreviewMouseMove({
        param($s, $e)
        if ($Script:IsUserDraggingSlider -and $PreviewMediaElement -and $PreviewMediaElement.NaturalDuration.HasTimeSpan) {
            $cur = [System.TimeSpan]::FromSeconds($SliderMediaTimeline.Value)
            $dur = $PreviewMediaElement.NaturalDuration.TimeSpan
            $curStr = "{0:mm\:ss}" -f $cur
            $durStr = "{0:mm\:ss}" -f $dur
            if ($TxtMediaTime) { $TxtMediaTime.Text = "$curStr / $durStr" }
        }
    })

    # Mouse release: single clean seek commit to the media player
    $SliderMediaTimeline.add_PreviewMouseLeftButtonUp({
        param($s, $e)
        $Script:IsUserDraggingSlider = $false
        Seek-MediaToSeconds $SliderMediaTimeline.Value
    })

    # Slider ValueChanged: keeps time display in sync during drag or native move-to-point
    $SliderMediaTimeline.add_ValueChanged({
        if ($PreviewMediaElement -and $PreviewMediaElement.NaturalDuration.HasTimeSpan) {
            $cur = [System.TimeSpan]::FromSeconds($SliderMediaTimeline.Value)
            $dur = $PreviewMediaElement.NaturalDuration.TimeSpan
            $curStr = "{0:mm\:ss}" -f $cur
            $durStr = "{0:mm\:ss}" -f $dur
            if ($TxtMediaTime) { $TxtMediaTime.Text = "$curStr / $durStr" }
        }
    })
}

# Volume Slider
if ($SliderMediaVolume) {
    $SliderMediaVolume.add_ValueChanged({
        if ($PreviewMediaElement) {
            $PreviewMediaElement.Volume = $SliderMediaVolume.Value
        }
        if ($TxtMediaMuteIcon) {
            if ($SliderMediaVolume.Value -le 0.01) {
                $TxtMediaMuteIcon.Text = [char]0xE74F
                $TxtMediaMuteIcon.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#F87171"))
            } else {
                $TxtMediaMuteIcon.Text = [char]0xE767
                $TxtMediaMuteIcon.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#A1A1AA"))
            }
        }
    })
}

# Debounce timer for smooth 60fps file scrolling
$Script:PreviewDebounceTimer = New-Object System.Windows.Threading.DispatcherTimer
$Script:PreviewDebounceTimer.Interval = [System.TimeSpan]::FromMilliseconds(70)
$Script:PreviewDebounceTimer.Add_Tick({
    $Script:PreviewDebounceTimer.Stop()
    if ($Script:PendingPreviewItem -and $Script:IsPreviewPaneOpen) {
        Update-LivePreviewPane $Script:PendingPreviewItem
    }
})

# ==============================================================================
# NATIVE WINDOWS CONTEXT MENU ACTIONS
# ==============================================================================
function Open-ExplorerSelectedItem {
    $selected = Get-ExplorerSelectedItem
    if ($selected -is [ZeroExplore.FileItem]) {
        if ($selected.IsDirectory) {
            Navigate-ExplorerFolder $selected.FullPath
        } else {
            try {
                [System.Diagnostics.Process]::Start((New-Object System.Diagnostics.ProcessStartInfo($selected.FullPath) -Property @{ UseShellExecute = $true })) | Out-Null
            } catch {
                try { Start-Process $selected.FullPath } catch {}
            }
        }
    }
}

function Open-ExplorerAsAdmin {
    $sel = Get-ExplorerSelectedItem
    if ($sel -is [ZeroExplore.FileItem]) {
        $path = $sel.FullPath
        if ($sel.IsDirectory) {
            try {
                Start-Process "wt.exe" -ArgumentList "-d `"$path`"" -Verb RunAs -ErrorAction Stop
            } catch {
                Start-Process "powershell.exe" -ArgumentList "-NoExit -Command `"Set-Location -LiteralPath '$path'`"" -Verb RunAs
            }
        } else {
            $ext = [System.IO.Path]::GetExtension($path).ToLowerInvariant()
            if ($ext -eq ".ps1") {
                Start-Process "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$path`"" -Verb RunAs
            } elseif ($ext -in @(".bat", ".cmd")) {
                Start-Process "cmd.exe" -ArgumentList "/c `"`"$path`"`"" -Verb RunAs
            } elseif ($ext -in @(".exe", ".msi")) {
                Start-Process -FilePath $path -Verb RunAs
            } else {
                try {
                    Start-Process -FilePath $path -Verb RunAs
                } catch {
                    try {
                        [System.Diagnostics.Process]::Start((New-Object System.Diagnostics.ProcessStartInfo($path) -Property @{ Verb = "RunAs"; UseShellExecute = $true })) | Out-Null
                    } catch {
                        try {
                            Start-Process -FilePath "notepad.exe" -ArgumentList "`"$path`"" -Verb RunAs
                        } catch {
                            [System.Windows.MessageBox]::Show("Could not launch '$($sel.Name)' as administrator: $($_.Exception.Message)", "Elevation Error", "OK", "Warning")
                        }
                    }
                }
            }
        }
    } elseif ($Script:ExplorerCurrentPath -and (Test-Path -LiteralPath $Script:ExplorerCurrentPath)) {
        $path = $Script:ExplorerCurrentPath
        try {
            Start-Process "wt.exe" -ArgumentList "-d `"$path`"" -Verb RunAs -ErrorAction Stop
        } catch {
            Start-Process "powershell.exe" -ArgumentList "-NoExit -Command `"Set-Location -LiteralPath '$path'`"" -Verb RunAs
        }
    }
}

function Get-WinRARPath {
    $paths = @(
        'C:\Program Files\WinRAR\WinRAR.exe',
        'C:\Program Files (x86)\WinRAR\WinRAR.exe',
        "$env:ProgramFiles\WinRAR\WinRAR.exe",
        "${env:ProgramFiles(x86)}\WinRAR\WinRAR.exe",
        "$env:LOCALAPPDATA\Programs\WinRAR\WinRAR.exe"
    )
    foreach ($p in $paths) {
        if ($p -and (Test-Path -LiteralPath $p)) { return $p }
    }
    try {
        $reg = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\WinRAR.exe' -ErrorAction SilentlyContinue).'(default)'
        if ($reg -and (Test-Path -LiteralPath $reg)) { return $reg }
    } catch {}
    try {
        $reg = (Get-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\WinRAR.exe' -ErrorAction SilentlyContinue).'(default)'
        if ($reg -and (Test-Path -LiteralPath $reg)) { return $reg }
    } catch {}
    try {
        $cmd = (Get-Command winrar.exe -ErrorAction SilentlyContinue).Source
        if ($cmd -and (Test-Path -LiteralPath $cmd)) { return $cmd }
    } catch {}
    return $null
}

function Execute-WinRARExtract([string]$mode) {
    $archiveList = @(".zip", ".rar", ".7z", ".tar", ".gz", ".tgz", ".bz2", ".tbz2", ".xz", ".txz", ".iso", ".cab", ".wim", ".arj", ".lzh")
    $selItems = Get-ExplorerSelectedItems
    $archives = @()
    if ($selItems) {
        foreach ($item in $selItems) {
            if ($item -is [ZeroExplore.FileItem] -and -not $item.IsDirectory) {
                $ext = [System.IO.Path]::GetExtension($item.FullPath).ToLowerInvariant()
                if ($ext -in $archiveList -and (Test-Path -LiteralPath $item.FullPath)) {
                    $archives += $item
                }
            }
        }
    }
    if ($archives.Count -eq 0) {
        $single = Get-ExplorerSelectedItem
        if ($single -is [ZeroExplore.FileItem] -and -not $single.IsDirectory) {
            $ext = [System.IO.Path]::GetExtension($single.FullPath).ToLowerInvariant()
            if ($ext -in $archiveList -and (Test-Path -LiteralPath $single.FullPath)) {
                $archives += $single
            }
        }
    }
    if ($archives.Count -eq 0) { return }

    $currentDir = if ($Script:ExplorerCurrentPath -and (Test-Path -LiteralPath $Script:ExplorerCurrentPath)) {
        $Script:ExplorerCurrentPath
    } else {
        [System.IO.Path]::GetDirectoryName($archives[0].FullPath)
    }

    $winrar = Get-WinRARPath

    if ($mode -eq "Dialog") {
        if ($winrar) {
            foreach ($arc in $archives) {
                $arcPath = $arc.FullPath
                # Authentic WinRAR command line for the "Extraction path and options" interactive dialog
                $winrarArgs = "x -iext -ver -- `"$arcPath`" `"?\`""
                try {
                    Start-Process -FilePath $winrar -ArgumentList $winrarArgs -WorkingDirectory $currentDir
                } catch {
                    [System.Windows.MessageBox]::Show("Failed to launch WinRAR: $($_.Exception.Message)", "Extraction Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
                }
            }
        } else {
            # Fallback to COM Shell verbs if WinRAR executable path was not detected directly
            try {
                $sh = New-Object -ComObject Shell.Application
                foreach ($arc in $archives) {
                    $folder = $sh.Namespace([System.IO.Path]::GetDirectoryName($arc.FullPath))
                    $item = $folder.ParseName([System.IO.Path]::GetFileName($arc.FullPath))
                    foreach ($v in $item.Verbs()) {
                        if (($v.Name -replace '&','') -like "*Extract files*") {
                            $v.DoIt()
                            break
                        }
                    }
                }
            } catch {
                [System.Windows.MessageBox]::Show("WinRAR executable was not found. Please install WinRAR to extract archives.", "WinRAR Not Found", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
            }
        }
        return
    }

    if ($winrar) {
        foreach ($arc in $archives) {
            $arcPath = $arc.FullPath
            $winrarArgs = switch ($mode) {
                "Open"   { "`"$arcPath`"" }
                "Here"   { "x -y `"$arcPath`" `"$currentDir`"" }
                default  { "x -y `"$arcPath`" `"$currentDir`"" }
            }
            try {
                if ($TxtTransferStatus) { $TxtTransferStatus.Text = "Extracting $($arc.Name)..." }
                $psi = New-Object System.Diagnostics.ProcessStartInfo
                $psi.FileName = $winrar
                $psi.Arguments = $winrarArgs
                $psi.WorkingDirectory = $currentDir
                $psi.UseShellExecute = $true
                [System.Diagnostics.Process]::Start($psi) | Out-Null
            } catch {
                try {
                    Start-Process -FilePath $winrar -ArgumentList $winrarArgs -WorkingDirectory $currentDir
                } catch {
                    [System.Windows.MessageBox]::Show("Failed to launch WinRAR: $($_.Exception.Message)", "Extraction Error", "OK", "Error")
                }
            }
        }
        $timer = New-Object System.Windows.Threading.DispatcherTimer
        $timer.Interval = [TimeSpan]::FromMilliseconds(700)
        $timer.add_Tick({
            param($s, $e)
            $s.Stop()
            Refresh-ExplorerCurrentDirectory
            if ($TxtTransferStatus) { $TxtTransferStatus.Text = "Extraction started with WinRAR." }
        })
        $timer.Start()
    } else {
        $hasErrors = $false
        foreach ($arc in $archives) {
            $arcPath = $arc.FullPath
            $ext = [System.IO.Path]::GetExtension($arcPath).ToLowerInvariant()
            if ($ext -eq ".zip") {
                $dest = if ($mode -eq "Folder") { Join-Path $currentDir $arc.BaseName } else { $currentDir }
                try {
                    if ($TxtTransferStatus) { $TxtTransferStatus.Text = "Extracting $($arc.Name)..." }
                    Expand-Archive -LiteralPath $arcPath -DestinationPath $dest -Force
                    if ($TxtTransferStatus) { $TxtTransferStatus.Text = "Extracted $($arc.Name) successfully." }
                } catch {
                    $hasErrors = $true
                }
            } else {
                $hasErrors = $true
            }
        }
        Refresh-ExplorerCurrentDirectory
        if ($hasErrors) {
            [System.Windows.MessageBox]::Show("WinRAR executable was not found. Please install WinRAR to extract RAR/7Z/TAR archives.", "WinRAR Required", "OK", "Warning")
        }
    }
}

function Show-ExplorerOpenWith {
    $selected = Get-ExplorerSelectedItem
    if ($selected -is [ZeroExplore.FileItem] -and -not $selected.IsDirectory) {
        [ZeroExplore.ShellNative]::ShowOpenWithDialog($selected.FullPath)
    }
}

function Open-ExplorerTerminal {
    $sel = Get-ExplorerSelectedItem
    $targetDir = if ($sel -is [ZeroExplore.FileItem] -and $sel.IsDirectory) { $sel.FullPath } else { $Script:ExplorerCurrentPath }
    if (-not (Test-Path -LiteralPath $targetDir)) { $targetDir = $Script:ExplorerCurrentPath }
    
    try {
        Start-Process "wt.exe" -ArgumentList "-d `"$targetDir`"" -ErrorAction Stop
    } catch {
        Start-Process "powershell.exe" -ArgumentList "-NoExit -Command `"Set-Location -LiteralPath '$targetDir'`""
    }
}

function Open-ExplorerInWindowsExplorer {
    $sel = Get-ExplorerSelectedItem
    $targetPath = if ($sel -is [ZeroExplore.FileItem]) { $sel.FullPath } else { $Script:ExplorerCurrentPath }
    if (-not (Test-Path -LiteralPath $targetPath)) { return }
    
    if (Test-Path -LiteralPath $targetPath -PathType Container) {
        Start-Process "explorer.exe" -ArgumentList "`"$targetPath`""
    } else {
        Start-Process "explorer.exe" -ArgumentList "/select,`"$targetPath`""
    }
}

function Pin-ExplorerToQuickAccess {
    $targetPath = $null
    $sel = Get-ExplorerSelectedItem
    if ($sel -is [ZeroExplore.FileItem]) {
        if ($sel.IsDirectory) {
            $targetPath = $sel.FullPath
        } else {
            $targetPath = [System.IO.Path]::GetDirectoryName($sel.FullPath)
        }
    } elseif ($Script:ExplorerCurrentPath) {
        $targetPath = $Script:ExplorerCurrentPath
    }

    if (-not $targetPath -or -not (Test-Path -LiteralPath $targetPath)) {
        if ($TxtTransferStatus) { $TxtTransferStatus.Text = "No valid folder selected to pin." }
        return
    }

    $normPath = [System.IO.Path]::GetFullPath($targetPath).TrimEnd('\')
    if ($Script:PinnedFolders -and $Script:PinnedFolders.Contains($normPath)) {
        Unpin-ExplorerQuickAccessPath $normPath
    } else {
        Pin-ExplorerQuickAccessPath $normPath
    }

    # Also invoke Windows Shell pintohome in background for native Windows sync
    try {
        $shell = New-Object -ComObject Shell.Application
        $folder = $shell.Namespace($targetPath)
        if ($folder) {
            $folder.Self.InvokeVerb("pintohome")
        }
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) | Out-Null
    } catch {}
}

function Copy-ExplorerSelectedAsPath {
    $selected = @(Get-ExplorerSelectedItems)
    if ($selected.Count -eq 0) {
        if ($Script:ExplorerCurrentPath) {
            [System.Windows.Clipboard]::SetText("`"$($Script:ExplorerCurrentPath)`"")
            $TxtTransferStatus.Text = "Copied current folder path to clipboard."
        }
        return
    }
    $paths = ($selected | Where-Object { $_ -is [ZeroExplore.FileItem] } | ForEach-Object { "`"$($_.FullPath)`"" }) -join [Environment]::NewLine
    [System.Windows.Clipboard]::SetText($paths)
    $TxtTransferStatus.Text = "Copied $($selected.Count) path(s) to clipboard."
}

function Create-ExplorerShortcut {
    $sel = Get-ExplorerSelectedItem
    if (-not ($sel -is [ZeroExplore.FileItem])) { return }
    $targetPath = $sel.FullPath
    if (-not (Test-Path -LiteralPath $targetPath)) { return }
    try {
        $dir = $Script:ExplorerCurrentPath
        $baseName = if ($sel.IsDirectory) { $sel.Name } else { [System.IO.Path]::GetFileNameWithoutExtension($sel.Name) }
        $shortcutPath = [System.IO.Path]::Combine($dir, "$baseName - Shortcut.lnk")
        $i = 2
        while (Test-Path -LiteralPath $shortcutPath) {
            $shortcutPath = [System.IO.Path]::Combine($dir, "$baseName - Shortcut ($i).lnk")
            $i++
        }
        $wsh = New-Object -ComObject WScript.Shell
        $sc = $wsh.CreateShortcut($shortcutPath)
        $sc.TargetPath = $targetPath
        $sc.WorkingDirectory = if ($sel.IsDirectory) { $targetPath } else { [System.IO.Path]::GetDirectoryName($targetPath) }
        $sc.Save()
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($wsh) | Out-Null
        Refresh-ExplorerCurrentDirectory
        $TxtTransferStatus.Text = "Created shortcut for '$($sel.Name)'."
    } catch {
        [System.Windows.MessageBox]::Show("Failed to create shortcut: $($_.Exception.Message)", "Shortcut Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    }
}

function Show-ExplorerProperties {
    $sel = Get-ExplorerSelectedItem
    $targetPath = if ($sel -is [ZeroExplore.FileItem]) { $sel.FullPath } else { $Script:ExplorerCurrentPath }
    if (-not $targetPath -or -not (Test-Path -LiteralPath $targetPath)) { return }
    [ZeroExplore.ShellNative]::ShowPropertiesDialog($targetPath)
}

function Show-ExplorerRenameDialog {
    $sel = Get-ExplorerSelectedItem
    if (-not ($sel -is [ZeroExplore.FileItem])) { return }
    $oldPath = $sel.FullPath
    $oldName = $sel.Name
    $isDir = $sel.IsDirectory
    
    $renameWindow = New-Object System.Windows.Window
    $renameWindow.Title = "Rename Item"
    $renameWindow.Width = 460
    $renameWindow.Height = 195
    $renameWindow.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterOwner
    $renameWindow.Owner = $Window
    $renameWindow.WindowStyle = [System.Windows.WindowStyle]::None
    $renameWindow.AllowsTransparency = $true
    $renameWindow.Background = [System.Windows.Media.Brushes]::Transparent
    $renameWindow.ResizeMode = [System.Windows.ResizeMode]::NoResize
    
    $xamlDialog = @'
<Border xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Background="#111115" BorderBrush="#352924" BorderThickness="1.5" CornerRadius="10">
  <Border.Effect>
    <DropShadowEffect BlurRadius="25" ShadowDepth="8" Opacity="0.85" Color="#000000" />
  </Border.Effect>
  <Grid>
    <Grid.RowDefinitions>
      <RowDefinition Height="38" />
      <RowDefinition Height="*" />
    </Grid.RowDefinitions>

    <!-- Custom Title Bar (Draggable, No PowerShell Icon) -->
    <Border Name="TitleBarRename" Grid.Row="0" Background="#16161D" BorderBrush="#252530" BorderThickness="0,0,0,1" CornerRadius="9,9,0,0">
      <DockPanel LastChildFill="True">
        <Button Name="BtnDialogClose" DockPanel.Dock="Right" Width="36" Height="36" Background="Transparent" BorderThickness="0" Foreground="#A1A1AA" Cursor="Hand" ToolTip="Close">
          <Button.Template>
            <ControlTemplate TargetType="Button">
              <Border Background="Transparent">
                <TextBlock Text="&#xE8BB;" FontFamily="Segoe MDL2 Assets" FontSize="11" HorizontalAlignment="Center" VerticalAlignment="Center" Foreground="{TemplateBinding Foreground}" />
              </Border>
            </ControlTemplate>
          </Button.Template>
        </Button>
        <StackPanel Orientation="Horizontal" VerticalAlignment="Center" Margin="14,0,0,0">
          <TextBlock Text="&#xE8AC;" FontFamily="Segoe MDL2 Assets" FontSize="13" Foreground="#c15f3c" VerticalAlignment="Center" Margin="0,0,8,0" />
          <TextBlock Text="Rename Item" FontSize="12" FontWeight="Bold" Foreground="#F5EDE0" VerticalAlignment="Center" />
        </StackPanel>
      </DockPanel>
    </Border>

    <!-- Body -->
    <Grid Grid.Row="1" Margin="18,14,18,16">
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto" />
        <RowDefinition Height="Auto" />
        <RowDefinition Height="*" />
      </Grid.RowDefinitions>

      <TextBlock Name="LblPrompt" Grid.Row="0" Text="Enter new name:" Foreground="#94A3B8" FontSize="11" FontWeight="SemiBold" Margin="0,0,0,8" />

      <Border Grid.Row="1" Background="#181822" BorderBrush="#2D2D3C" BorderThickness="1" CornerRadius="6" Height="34" Padding="10,0">
        <TextBox Name="TxtRenameInput" Background="Transparent" BorderThickness="0" Foreground="#FFFFFF" FontSize="12" FontWeight="SemiBold" VerticalAlignment="Center" SelectionBrush="#c15f3c" />
      </Border>

      <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Bottom">
        <Button Name="BtnRenameOk" Width="85" Height="30" Margin="0,0,8,0" Background="#c15f3c" Foreground="#FFFFFF" FontWeight="Bold" FontSize="11.5" Cursor="Hand">
          <Button.Template>
            <ControlTemplate TargetType="Button">
              <Border Background="{TemplateBinding Background}" CornerRadius="6">
                <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" />
              </Border>
            </ControlTemplate>
          </Button.Template>
          Rename
        </Button>
        <Button Name="BtnRenameCancel" Width="85" Height="30" Background="#1E1E26" BorderBrush="#2B2B38" BorderThickness="1" Foreground="#D4D4D8" FontWeight="SemiBold" FontSize="11.5" Cursor="Hand">
          <Button.Template>
            <ControlTemplate TargetType="Button">
              <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="6">
                <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" />
              </Border>
            </ControlTemplate>
          </Button.Template>
          Cancel
        </Button>
      </StackPanel>
    </Grid>
  </Grid>
</Border>
'@

    $reader = New-Object System.Xml.XmlNodeReader ([xml]$xamlDialog)
    $root = [System.Windows.Markup.XamlReader]::Load($reader)
    $renameWindow.Content = $root

    $titleBar  = $root.FindName("TitleBarRename")
    $btnClose  = $root.FindName("BtnDialogClose")
    $lbl       = $root.FindName("LblPrompt")
    $txt       = $root.FindName("TxtRenameInput")
    $btnOk     = $root.FindName("BtnRenameOk")
    $btnCancel = $root.FindName("BtnRenameCancel")

    $lbl.Text = "Enter new name for '$oldName':"
    $txt.Text = $oldName

    if ($titleBar) {
        $titleBar.add_MouseLeftButtonDown({ $renameWindow.DragMove() })
    }
    if ($btnClose) {
        $btnClose.add_Click({ $renameWindow.Close() })
    }
    
    $doRename = {
        $newName = $txt.Text.Trim()
        if ($newName -and $newName -ne $oldName) {
            $dir = [System.IO.Path]::GetDirectoryName($oldPath)
            $newPath = [System.IO.Path]::Combine($dir, $newName)
            try {
                if ($isDir) {
                    [System.IO.Directory]::Move($oldPath, $newPath)
                } else {
                    [System.IO.File]::Move($oldPath, $newPath)
                }
                $renameWindow.Close()
                Refresh-ExplorerCurrentDirectory
                $TxtTransferStatus.Text = "Renamed '$oldName' to '$newName'."
            } catch {
                [System.Windows.MessageBox]::Show("Failed to rename: $($_.Exception.Message)", "Rename Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
            }
        } else {
            $renameWindow.Close()
        }
    }
    
    $btnOk.add_Click($doRename)
    $btnCancel.add_Click({ $renameWindow.Close() })
    $txt.add_KeyDown({
        if ($_.Key -eq [System.Windows.Input.Key]::Enter) { & $doRename }
        elseif ($_.Key -eq [System.Windows.Input.Key]::Escape) { $renameWindow.Close() }
    })
    $renameWindow.add_KeyDown({
        if ($_.Key -eq [System.Windows.Input.Key]::Escape) { $renameWindow.Close() }
    })
    
    $renameWindow.add_Loaded({
        $txt.Focus() | Out-Null
        if (-not $isDir) {
            $dotIdx = $oldName.LastIndexOf('.')
            if ($dotIdx -gt 0) {
                $txt.Select(0, $dotIdx)
            } else {
                $txt.SelectAll()
            }
        } else {
            $txt.SelectAll()
        }
    })
    
    $renameWindow.ShowDialog() | Out-Null
}

function Create-NewDocumentFile([string]$extension, [string]$defaultName) {
    Show-ExplorerFilesView
    $current = $Script:ExplorerCurrentPath
    $baseFileName = "$defaultName$extension"
    $newFile = [System.IO.Path]::Combine($current, $baseFileName)
    $count = 2
    while (Test-Path -LiteralPath $newFile) {
        $newFile = [System.IO.Path]::Combine($current, "$defaultName ($count)$extension")
        $count++
    }
    try {
        [System.IO.File]::WriteAllText($newFile, "")
        Refresh-ExplorerCurrentDirectory
        $TxtTransferStatus.Text = "Created file: $([System.IO.Path]::GetFileName($newFile))"
    } catch {
        [System.Windows.MessageBox]::Show("Failed to create file:`n$_", "ZeroExplore Error", "OK", "Error")
    }
}


# Responsive DataGrid Columns (Always show File Name in narrow window instead of collapsing it)
if ($ExplorerDataGrid) {
    $ExplorerDataGrid.add_SizeChanged({
        param($s, $e)
        Update-ResponsiveExplorerColumns $e.NewSize.Width
    })
}

function On-ExplorerSelectionChanged {
    $selectedList = Get-ExplorerSelectedItems
    if ($selectedList.Count -eq 0) {
        $TxtExplorerSelectedInfo.Text = ""
        $Script:PendingPreviewItem = $null
        Reset-LivePreviewPane
        return
    }

    if ($selectedList.Count -eq 1) {
        $singleItem = $selectedList[0]
        if ($singleItem -is [ZeroExplore.FileItem]) {
            $TxtExplorerSelectedInfo.Text = "Selected: 1 item ($($singleItem.SizeFormatted))"
            if ($Script:IsPreviewPaneOpen) {
                try {
                    $mediaTimer.Stop()
                    $PreviewMediaElement.Stop()
                    $PreviewMediaElement.Source = $null
                } catch {}
                $Script:PendingPreviewItem = $singleItem
                $Script:PreviewDebounceTimer.Stop()
                $Script:PreviewDebounceTimer.Start()
            }
        }
    } else {
        $totalSelBytes = 0
        $fileCount = 0
        $dirCount  = 0
        foreach ($it in $selectedList) {
            if ($it -is [ZeroExplore.FileItem]) {
                if ($it.IsDirectory) { $dirCount++ }
                else { $fileCount++; $totalSelBytes += $it.SizeBytes }
            }
        }
        $formatted = [ZeroExplore.FileExplorerEngine]::FormatSize($totalSelBytes)
        $TxtExplorerSelectedInfo.Text = "Selected: $($selectedList.Count) items ($formatted)"
        $Script:PendingPreviewItem = $null
        Reset-LivePreviewPane
        $TxtPreviewFileName.Text = "$($selectedList.Count) items selected"
        $TxtPreviewMetaDetails.Text = "$fileCount files, $dirCount folders $([char]0x2022) Total $formatted"
    }
}

function On-ExplorerItemActivated($selected) {
    if ($selected -is [ZeroExplore.FileItem] -and -not $selected.IsBanner) {
        if ($selected.IsDirectory) {
            Navigate-ExplorerFolder $selected.FullPath
        } else {
            try {
                [System.Diagnostics.Process]::Start((New-Object System.Diagnostics.ProcessStartInfo($selected.FullPath) -Property @{ UseShellExecute = $true })) | Out-Null
            } catch {
                try { Start-Process $selected.FullPath } catch {}
            }
        }
    }
}

$ExplorerDataGrid.add_SelectionChanged({ On-ExplorerSelectionChanged })
$ExplorerDataGrid.add_MouseDoubleClick({ On-ExplorerItemActivated (Get-ExplorerSelectedItem) })

# Ensure right-click selects item before opening context menu in DataGrid
$ExplorerDataGrid.add_PreviewMouseRightButtonDown({
    param($s, $e)
    $pt = $e.GetPosition($ExplorerDataGrid)
    $hit = [System.Windows.Media.VisualTreeHelper]::HitTest($ExplorerDataGrid, $pt)
    if ($hit -and $hit.VisualHit) {
        $parent = $hit.VisualHit
        while ($parent -and -not ($parent -is [System.Windows.Controls.DataGridRow])) {
            $parent = [System.Windows.Media.VisualTreeHelper]::GetParent($parent)
        }
        if ($parent -is [System.Windows.Controls.DataGridRow]) {
            if (-not $parent.IsSelected) {
                $ExplorerDataGrid.SelectedItem = $parent.DataContext
            }
        }
    }
})

if ($ExplorerIconGrid) {
    $ExplorerIconGrid.add_SelectionChanged({ On-ExplorerSelectionChanged })
    $ExplorerIconGrid.add_MouseDoubleClick({ On-ExplorerItemActivated (Get-ExplorerSelectedItem) })
    
    # Context Menu attachment
    if ($ExplorerContextMenu) {
        $ExplorerIconGrid.ContextMenu = $ExplorerContextMenu
    }

    # Ensure right-click selects item before opening context menu
    $ExplorerIconGrid.add_PreviewMouseRightButtonDown({
        param($s, $e)
        $pt = $e.GetPosition($ExplorerIconGrid)
        $hit = [System.Windows.Media.VisualTreeHelper]::HitTest($ExplorerIconGrid, $pt)
        if ($hit -and $hit.VisualHit) {
            $parent = $hit.VisualHit
            while ($parent -and -not ($parent -is [System.Windows.Controls.ListBoxItem])) {
                $parent = [System.Windows.Media.VisualTreeHelper]::GetParent($parent)
            }
            if ($parent -is [System.Windows.Controls.ListBoxItem]) {
                if (-not $parent.IsSelected) {
                    $ExplorerIconGrid.SelectedItem = $parent.DataContext
                }
            }
        }
    })

    # Enter key folder navigation / activation in Icon Grid
    $ExplorerIconGrid.add_KeyDown({
        param($s, $e)
        if ($e.Key -eq [System.Windows.Input.Key]::Enter) {
            $sel = Get-ExplorerSelectedItem
            if ($sel) {
                On-ExplorerItemActivated $sel
                $e.Handled = $true
            }
        }
    })
}

# Ctrl + MouseWheel Zoom to cycle View Modes (Details -> Medium Icons -> Large Icons)
$onCtrlWheelZoom = {
    param($s, $e)
    $ctrl = [System.Windows.Input.Keyboard]::Modifiers -band [System.Windows.Input.ModifierKeys]::Control
    if ($ctrl) {
        if ($e.Delta -gt 0) {
            if ($Script:CurrentViewMode -eq "Details") {
                Set-ExplorerViewMode "MediumIcons"
            } elseif ($Script:CurrentViewMode -eq "MediumIcons") {
                Set-ExplorerViewMode "LargeIcons"
            }
        } elseif ($e.Delta -lt 0) {
            if ($Script:CurrentViewMode -eq "LargeIcons") {
                Set-ExplorerViewMode "MediumIcons"
            } elseif ($Script:CurrentViewMode -eq "MediumIcons") {
                Set-ExplorerViewMode "Details"
            }
        }
        $e.Handled = $true
    }
}
$ExplorerDataGrid.add_PreviewMouseWheel($onCtrlWheelZoom)
if ($ExplorerIconGrid) { $ExplorerIconGrid.add_PreviewMouseWheel($onCtrlWheelZoom) }

# ==============================================================================
# KEYBOARD SHORTCUTS (PreviewKeyDown + CommandBindings for 100% reliable Copy/Cut/Paste)
# ==============================================================================

# Global Window-Level PreviewKeyDown (Captures keys reliably across Window, DataGrid & Rows)
$Window.add_PreviewKeyDown({
    param($s, $e)
    $ctrl = [System.Windows.Input.Keyboard]::Modifiers -band [System.Windows.Input.ModifierKeys]::Control

    # Allow standard text typing & selection when user is editing in a TextBox (e.g. Search/Path/Rename/PreviewEditor)
    $focused = [System.Windows.Input.FocusManager]::GetFocusedElement($Window)
    if ($focused -is [System.Windows.Controls.TextBox] -or $focused -is [System.Windows.Controls.Primitives.TextBoxBase]) {
        if ($focused -eq $TxtPreviewContent) {
            if ($e.Key -eq [System.Windows.Input.Key]::S -and $ctrl) {
                Save-PreviewTextContent
                $e.Handled = $true
                return
            } elseif ($e.Key -eq [System.Windows.Input.Key]::Escape) {
                Exit-PreviewEditMode $true
                $e.Handled = $true
                return
            }
        }
        return
    }

    if ($e.Key -eq [System.Windows.Input.Key]::T -and $ctrl -and -not $e.KeyboardDevice.Modifiers.HasFlag([System.Windows.Input.ModifierKeys]::Shift)) {
        Add-WorkspaceTab
        $e.Handled = $true
        return
    } elseif ($e.Key -eq [System.Windows.Input.Key]::W -and $ctrl) {
        if ($Script:ActiveWorkspaceId) {
            Close-WorkspaceTab $Script:ActiveWorkspaceId
        }
        $e.Handled = $true
        return
    } elseif ($e.Key -eq [System.Windows.Input.Key]::Tab -and $ctrl) {
        Cycle-WorkspaceTab
        $e.Handled = $true
        return
    } elseif ($e.Key -eq [System.Windows.Input.Key]::F10 -or ($e.Key -eq [System.Windows.Input.Key]::T -and $ctrl -and $e.KeyboardDevice.Modifiers.HasFlag([System.Windows.Input.ModifierKeys]::Shift))) {
        Toggle-HyprlandTilingMode
        $e.Handled = $true
        return
    }

    if ($e.Key -eq [System.Windows.Input.Key]::C -and $ctrl) {
        Set-ExplorerClipboard "Copy"
        $e.Handled = $true
    } elseif ($e.Key -eq [System.Windows.Input.Key]::X -and $ctrl) {
        Set-ExplorerClipboard "Cut"
        $e.Handled = $true
    } elseif ($e.Key -eq [System.Windows.Input.Key]::V -and $ctrl) {
        Execute-ExplorerPaste
        $e.Handled = $true
    } elseif ($e.Key -eq [System.Windows.Input.Key]::A -and $ctrl) {
        Select-AllExplorerItems
        $e.Handled = $true
    } elseif ($e.Key -eq [System.Windows.Input.Key]::Delete) {
        Delete-SelectedItems
        $e.Handled = $true
    } elseif ($e.Key -eq [System.Windows.Input.Key]::F2) {
        Show-ExplorerRenameDialog
        $e.Handled = $true
    } elseif ($e.Key -eq [System.Windows.Input.Key]::F5) {
        Refresh-ExplorerCurrentDirectory
        $e.Handled = $true
    } elseif ($e.Key -eq [System.Windows.Input.Key]::System -and $e.SystemKey -eq [System.Windows.Input.Key]::Enter) {
        Show-ExplorerProperties
        $e.Handled = $true
    } elseif ($e.Key -eq [System.Windows.Input.Key]::Back) {
        $parent = [System.IO.Path]::GetDirectoryName($Script:ExplorerCurrentPath)
        if ($parent) { Navigate-ExplorerFolder $parent }
        $e.Handled = $true
    }
})

# Enter Key Folder Navigation on DataGrid
$ExplorerDataGrid.add_KeyDown({
    param($s, $e)
    if ($e.Key -eq [System.Windows.Input.Key]::Enter) {
        $selected = $ExplorerDataGrid.SelectedItem
        if ($selected -is [ZeroExplore.FileItem] -and $selected.IsDirectory) {
            Navigate-ExplorerFolder $selected.FullPath
            $e.Handled = $true
        }
    }
})

# CommandBindings to fully support Windows routed commands (Ctrl+C, Ctrl+X, Ctrl+V, Delete)
$Window.CommandBindings.Add((New-Object System.Windows.Input.CommandBinding([System.Windows.Input.ApplicationCommands]::Copy, {
    param($s, $e)
    $focused = [System.Windows.Input.FocusManager]::GetFocusedElement($Window)
    if (-not ($focused -is [System.Windows.Controls.TextBox])) {
        Set-ExplorerClipboard "Copy"
        $e.Handled = $true
    }
}))) | Out-Null

$Window.CommandBindings.Add((New-Object System.Windows.Input.CommandBinding([System.Windows.Input.ApplicationCommands]::Cut, {
    param($s, $e)
    $focused = [System.Windows.Input.FocusManager]::GetFocusedElement($Window)
    if (-not ($focused -is [System.Windows.Controls.TextBox])) {
        Set-ExplorerClipboard "Cut"
        $e.Handled = $true
    }
}))) | Out-Null

$Window.CommandBindings.Add((New-Object System.Windows.Input.CommandBinding([System.Windows.Input.ApplicationCommands]::Paste, {
    param($s, $e)
    $focused = [System.Windows.Input.FocusManager]::GetFocusedElement($Window)
    if (-not ($focused -is [System.Windows.Controls.TextBox])) {
        Execute-ExplorerPaste
        $e.Handled = $true
    }
}))) | Out-Null

$Window.CommandBindings.Add((New-Object System.Windows.Input.CommandBinding([System.Windows.Input.ApplicationCommands]::Delete, {
    param($s, $e)
    $focused = [System.Windows.Input.FocusManager]::GetFocusedElement($Window)
    if (-not ($focused -is [System.Windows.Controls.TextBox])) {
        Delete-SelectedItems
        $e.Handled = $true
    }
}))) | Out-Null



# ==============================================================================
# CONTEXT MENU DYNAMIC BEHAVIOR & ACTION WIRING
# ==============================================================================
if ($ExplorerContextMenu) {
    $ExplorerContextMenu.add_Opened({
        $selectedItemsList = Get-ExplorerSelectedItems
        $hasItem = ($selectedItemsList.Count -gt 0)
        $hasClipboard = ($Script:ClipboardItems.Count -gt 0)
        try {
            if (-not $hasClipboard -and [System.Windows.Clipboard]::ContainsFileDropList()) {
                $hasClipboard = $true
            }
        } catch {}

        if ($CtxMenuPinQuick) {
            $targetDir = $null
            $sel = Get-ExplorerSelectedItem
            if ($sel -is [ZeroExplore.FileItem]) {
                if ($sel.IsDirectory) { $targetDir = $sel.FullPath }
            } elseif ($Script:ExplorerCurrentPath) {
                $targetDir = $Script:ExplorerCurrentPath
            }
            $isFolderTarget = [bool]($targetDir -and (Test-Path -LiteralPath $targetDir -PathType Container))
            $CtxMenuPinQuick.IsEnabled = $isFolderTarget
            if ($isFolderTarget) {
                $norm = [System.IO.Path]::GetFullPath($targetDir).TrimEnd('\')
                $isAlreadyPinned = ($Script:PinnedFolders -and $Script:PinnedFolders.Contains($norm))
                if ($isAlreadyPinned) {
                    $CtxMenuPinQuick.Header = "Unpin from Quick Access"
                } else {
                    $CtxMenuPinQuick.Header = "Pin to Quick Access"
                }
            } else {
                $CtxMenuPinQuick.Header = "Pin to Quick Access"
            }
        }

        if ($CtxMenuOpen)         { $CtxMenuOpen.IsEnabled = $hasItem }
        if ($CtxMenuOpenAdmin) {
            if ($hasItem) {
                $sel = Get-ExplorerSelectedItem
                if ($sel -is [ZeroExplore.FileItem]) {
                    if ($sel.IsDirectory) {
                        $CtxMenuOpenAdmin.Header = "Open Terminal as administrator"
                    } else {
                        $ext = [System.IO.Path]::GetExtension($sel.FullPath).ToLowerInvariant()
                        if ($ext -in @(".exe", ".bat", ".cmd", ".msi", ".ps1")) {
                            $CtxMenuOpenAdmin.Header = "Run as administrator"
                        } else {
                            $CtxMenuOpenAdmin.Header = "Open as administrator"
                        }
                    }
                } else {
                    $CtxMenuOpenAdmin.Header = "Run as administrator"
                }
                $CtxMenuOpenAdmin.IsEnabled = $true
            } else {
                $CtxMenuOpenAdmin.Header = "Open Terminal as administrator"
                $CtxMenuOpenAdmin.IsEnabled = [bool]($Script:ExplorerCurrentPath -and (Test-Path -LiteralPath $Script:ExplorerCurrentPath))
            }
        }

        $isArchive = $false
        $archiveName = ""
        $selectedArchives = @()
        $archiveList = @(".zip", ".rar", ".7z", ".tar", ".gz", ".tgz", ".bz2", ".tbz2", ".xz", ".txz", ".iso", ".cab", ".wim", ".arj", ".lzh")
        if ($hasItem) {
            foreach ($it in $selectedItemsList) {
                if ($it -is [ZeroExplore.FileItem] -and -not $it.IsDirectory) {
                    $ext = [System.IO.Path]::GetExtension($it.FullPath).ToLowerInvariant()
                    if ($ext -in $archiveList -or ($Script:ArchiveExtensions -and $Script:ArchiveExtensions.Contains($ext))) {
                        $selectedArchives += $it
                    }
                }
            }
            if ($selectedArchives.Count -gt 0) {
                $isArchive = $true
                $archiveName = $selectedArchives[0].BaseName
            }
        }

        $archiveVis = if ($isArchive) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
        if ($CtxSepArchiveTop)    { $CtxSepArchiveTop.Visibility = $archiveVis }
        if ($CtxMenuWinRAROpen)   { $CtxMenuWinRAROpen.Visibility = $archiveVis }
        if ($CtxMenuExtractDialog){ $CtxMenuExtractDialog.Visibility = $archiveVis }
        if ($CtxMenuExtractHere)  { $CtxMenuExtractHere.Visibility = $archiveVis }
        if ($CtxSepArchiveBottom) { $CtxSepArchiveBottom.Visibility = $archiveVis }

        $currentSelItem = Get-ExplorerSelectedItem
        if ($CtxMenuOpenWith)     { $CtxMenuOpenWith.IsEnabled = ($hasItem -and -not ($currentSelItem -is [ZeroExplore.FileItem] -and $currentSelItem.IsDirectory)) }
        if ($CtxMenuCut)          { $CtxMenuCut.IsEnabled = $hasItem }
        if ($CtxMenuCopy)         { $CtxMenuCopy.IsEnabled = $hasItem }
        if ($CtxMenuCopyPath) {
            $CtxMenuCopyPath.Header = if ($hasItem) { "Copy as path" } else { "Copy directory path" }
            $CtxMenuCopyPath.InputGestureText = if ($hasItem) { "Shift+Ctrl+C" } else { "" }
        }
        if ($CtxMenuPaste)        { $CtxMenuPaste.IsEnabled = $hasClipboard }
        if ($CtxMenuShortcut)     { $CtxMenuShortcut.IsEnabled = $hasItem }
        if ($CtxMenuDelete)       { $CtxMenuDelete.IsEnabled = $hasItem }
        if ($CtxMenuRename)       { $CtxMenuRename.IsEnabled = $hasItem }
        if ($CtxMenuProperties) {
            $CtxMenuProperties.Header = if ($hasItem) { "Properties" } else { "Directory Properties" }
        }
    })
}

if ($CtxMenuOpen)            { $CtxMenuOpen.add_Click({ Open-ExplorerSelectedItem }) }
if ($CtxMenuOpenAdmin)       { $CtxMenuOpenAdmin.add_Click({ Open-ExplorerAsAdmin }) }
if ($CtxMenuWinRAROpen)      { $CtxMenuWinRAROpen.add_Click({ Execute-WinRARExtract "Open" }) }
if ($CtxMenuExtractDialog)   { $CtxMenuExtractDialog.add_Click({ Execute-WinRARExtract "Dialog" }) }
if ($CtxMenuExtractHere)     { $CtxMenuExtractHere.add_Click({ Execute-WinRARExtract "Here" }) }
if ($CtxMenuOpenWith)        { $CtxMenuOpenWith.add_Click({ Show-ExplorerOpenWith }) }
if ($CtxMenuOpenTerminal)    { $CtxMenuOpenTerminal.add_Click({ Open-ExplorerTerminal }) }
if ($CtxMenuOpenExplorer)    { $CtxMenuOpenExplorer.add_Click({ Open-ExplorerInWindowsExplorer }) }
if ($CtxMenuPinQuick)        { $CtxMenuPinQuick.add_Click({ Pin-ExplorerToQuickAccess }) }
if ($CtxMenuCut)             { $CtxMenuCut.add_Click({ Set-ExplorerClipboard "Cut" }) }
if ($CtxMenuCopy)            { $CtxMenuCopy.add_Click({ Set-ExplorerClipboard "Copy" }) }
if ($CtxMenuCopyPath)        { $CtxMenuCopyPath.add_Click({ Copy-ExplorerSelectedAsPath }) }
if ($CtxMenuPaste)           { $CtxMenuPaste.add_Click({ Execute-ExplorerPaste }) }
if ($CtxMenuShortcut)        { $CtxMenuShortcut.add_Click({ Create-ExplorerShortcut }) }
if ($CtxMenuDelete)          { $CtxMenuDelete.add_Click({ Delete-SelectedItems }) }
if ($CtxMenuRename)          { $CtxMenuRename.add_Click({ Show-ExplorerRenameDialog }) }
if ($CtxMenuNewFolder)       { $CtxMenuNewFolder.add_Click({ Execute-CreateNewFolder }) }
if ($CtxMenuNewTxt)          { $CtxMenuNewTxt.add_Click({ Create-NewDocumentFile ".txt" "New Text Document" }) }
if ($CtxMenuNewPs1)          { $CtxMenuNewPs1.add_Click({ Create-NewDocumentFile ".ps1" "New PowerShell Script" }) }
if ($CtxMenuNewBat)          { $CtxMenuNewBat.add_Click({ Create-NewDocumentFile ".bat" "New Batch Script" }) }
if ($CtxMenuRefresh)         { $CtxMenuRefresh.add_Click({ Refresh-ExplorerCurrentDirectory }) }
if ($CtxMenuProperties)      { $CtxMenuProperties.add_Click({ Show-ExplorerProperties }) }

# ==============================================================================
# TOOLBAR & NAVIGATION WIRING
# ==============================================================================

# 1. History & Navigation Buttons
if ($BtnExplorerBack) {
    $BtnExplorerBack.add_Click({
        if ($Script:ExplorerHistoryIndex -gt 0) {
            $Script:ExplorerHistoryIndex--
            Navigate-ExplorerFolder $Script:ExplorerHistory[$Script:ExplorerHistoryIndex] $false
        }
    })
}

if ($BtnExplorerForward) {
    $BtnExplorerForward.add_Click({
        if ($Script:ExplorerHistoryIndex -lt ($Script:ExplorerHistory.Count - 1)) {
            $Script:ExplorerHistoryIndex++
            Navigate-ExplorerFolder $Script:ExplorerHistory[$Script:ExplorerHistoryIndex] $false
        }
    })
}

if ($BtnExplorerUp) {
    $BtnExplorerUp.add_Click({
        $parent = [System.IO.Path]::GetDirectoryName($Script:ExplorerCurrentPath)
        if ($parent) { Navigate-ExplorerFolder $parent }
    })
}

if ($BtnExplorerRefresh) {
    $BtnExplorerRefresh.add_Click({
        Refresh-ExplorerCurrentDirectory
    })
}

if ($BtnExplorerHome) {
    $BtnExplorerHome.add_Click({
        $homePath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::UserProfile)
        Navigate-ExplorerFolder $homePath
    })
}

if ($BtnExplorerGo) {
    $BtnExplorerGo.add_Click({
        if ($TxtExplorerPath) {
            Navigate-ExplorerFolder $TxtExplorerPath.Text.Trim()
        }
    })
}

if ($TxtExplorerPath) {
    $TxtExplorerPath.add_KeyDown({
        if ($_.Key -eq [System.Windows.Input.Key]::Enter) {
            Navigate-ExplorerFolder $TxtExplorerPath.Text.Trim()
            $_.Handled = $true
        }
    })
}

# 2. Live Directory Search / Filter
if ($TxtExplorerFilter) {
    $TxtExplorerFilter.add_TextChanged({
        Apply-ExplorerFilter
    })
}

# 3. Quick Access Sidebar Folders (Click & Dark Context Menus)
function Attach-QuickAccessContextMenu($borderElement, [string]$targetPath) {
    if (-not $borderElement -or -not $targetPath) { return }
    $cm = New-DarkContextMenu
    $cleanPath = $targetPath
    $miOpen = New-DarkMenuItem "Open" ([char]0xED25) "#38BDF8" {
        Show-ExplorerFilesView
        Navigate-ExplorerFolder $cleanPath
    }.GetNewClosure()
    $cm.Items.Add($miOpen) | Out-Null

    $miAdmin = New-DarkMenuItem "Open Terminal as administrator" ([char]0xE7EF) "#F59E0B" {
        try {
            Start-Process "wt.exe" -ArgumentList "-d `"$cleanPath`"" -Verb RunAs -ErrorAction Stop
        } catch {
            Start-Process "powershell.exe" -ArgumentList "-NoExit -Command `"Set-Location -LiteralPath '$cleanPath'`"" -Verb RunAs
        }
    }.GetNewClosure()
    $cm.Items.Add($miAdmin) | Out-Null

    $miExplorer = New-DarkMenuItem "Open in Windows Explorer" ([char]0xE8A7) "#F59E0B" {
        Start-Process "explorer.exe" -ArgumentList "`"$cleanPath`""
    }.GetNewClosure()
    $cm.Items.Add($miExplorer) | Out-Null

    $borderElement.ContextMenu = $cm
}

Attach-QuickAccessContextMenu $Border_Quick_Desktop   ([Environment]::GetFolderPath("Desktop"))
Attach-QuickAccessContextMenu $Border_Quick_Downloads (Join-Path $HOME "Downloads")
Attach-QuickAccessContextMenu $Border_Quick_Documents ([Environment]::GetFolderPath("MyDocuments"))
Attach-QuickAccessContextMenu $Border_Quick_AppData   ($env:LOCALAPPDATA)
Attach-QuickAccessContextMenu $Border_Quick_Temp      ([System.IO.Path]::GetTempPath())

if ($BtnQuickDesktop) {
    $BtnQuickDesktop.add_Click({
        Show-ExplorerFilesView
        Navigate-ExplorerFolder ([System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Desktop))
    })
}

if ($BtnQuickDownloads) {
    $BtnQuickDownloads.add_Click({
        Show-ExplorerFilesView
        $downPath = [System.IO.Path]::Combine([System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::UserProfile), "Downloads")
        if (Test-Path -LiteralPath $downPath) {
            Navigate-ExplorerFolder $downPath
        } else {
            Navigate-ExplorerFolder ([System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::UserProfile))
        }
    })
}

if ($BtnQuickDocuments) {
    $BtnQuickDocuments.add_Click({
        Show-ExplorerFilesView
        Navigate-ExplorerFolder ([System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::MyDocuments))
    })
}

if ($BtnQuickAppData) {
    $BtnQuickAppData.add_Click({
        Show-ExplorerFilesView
        Navigate-ExplorerFolder ([System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::LocalApplicationData))
    })
}

if ($BtnQuickTemp) {
    $BtnQuickTemp.add_Click({
        Show-ExplorerFilesView
        Navigate-ExplorerFolder ([System.IO.Path]::GetTempPath())
    })
}

if ($BtnQuickRecycleBin) {
    $BtnQuickRecycleBin.add_Click({
        Set-ActiveSidebarItem "Quick_RecycleBin"
        Start-Process "explorer.exe" -ArgumentList "shell:RecycleBinFolder"
    })
}

if ($Border_Quick_RecycleBin) {
    $cmRb = New-DarkContextMenu

    $miOpenRb = New-DarkMenuItem "Open Recycle Bin" ([char]0xED25) "#38BDF8" {
        Set-ActiveSidebarItem "Quick_RecycleBin"
        Start-Process "explorer.exe" -ArgumentList "shell:RecycleBinFolder"
    }.GetNewClosure()
    $cmRb.Items.Add($miOpenRb) | Out-Null

    $miEmptyRb = New-DarkMenuItem "Empty Recycle Bin" ([char]0xE74D) "#EF4444" {
        $ans = [System.Windows.MessageBox]::Show("Are you sure you want to permanently delete all items in the Recycle Bin?", "ZeroExplore - Empty Recycle Bin", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
        if ($ans -eq [System.Windows.MessageBoxResult]::Yes) {
            try {
                Clear-RecycleBin -Force -ErrorAction Stop
                if ($TxtTransferStatus) { $TxtTransferStatus.Text = "Recycle Bin emptied successfully." }
            } catch {
                if ($TxtTransferStatus) { $TxtTransferStatus.Text = "Recycle Bin is already empty." }
            }
        }
    }.GetNewClosure()
    $cmRb.Items.Add($miEmptyRb) | Out-Null

    $Border_Quick_RecycleBin.ContextMenu = $cmRb
}

# 4. Preview Pane Toggles
if ($BtnTogglePreviewPane) {
    $BtnTogglePreviewPane.add_Click({ Toggle-PreviewPane })
}

if ($BtnToggleViewMode) {
    $BtnToggleViewMode.add_Click({ Cycle-ExplorerViewMode })
}

function Show-ExplorerSortMenu {
    if (-not $BtnToggleSort) { return }
    if ($Script:ActiveSortMenu -and $Script:ActiveSortMenu.IsOpen) {
        $Script:ActiveSortMenu.IsOpen = $false
        $Script:ActiveSortMenu = $null
        return
    }

    $sortMenu = New-DarkContextMenu
    $Script:ActiveSortMenu = $sortMenu
    $sortMenu.PlacementTarget = $BtnToggleSort
    $sortMenu.Placement = [System.Windows.Controls.Primitives.PlacementMode]::Bottom
    $sortMenu.add_Closed({
        $Script:ActiveSortMenu = $null
    })

    $addSortOption = {
        param([string]$header, [string]$field, [bool]$ascending, [string]$color)
        $isActive = ($Script:CurrentSortField -eq $field -and $Script:CurrentSortAscending -eq $ascending)
        $iconGlyph = if ($isActive) { [char]0xE73E } else { if ($ascending) { [char]0xE70E } else { [char]0xE70D } }
        $iconColor = if ($isActive) { "#38BDF8" } else { "#5A5A66" }

        $targetField = $field
        $targetAsc = [bool]$ascending
        $clickAction = {
            Set-ExplorerSortMode $targetField $targetAsc
        }.GetNewClosure()

        $item = New-DarkMenuItem $header $iconGlyph $iconColor $clickAction
        if ($isActive) {
            $item.FontWeight = [System.Windows.FontWeights]::Bold
            $item.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#38BDF8")
        }
        $sortMenu.Items.Add($item) | Out-Null
    }

    & $addSortOption "Name (A to Z)" "Name" $true "#38BDF8"
    & $addSortOption "Name (Z to A)" "Name" $false "#38BDF8"
    $sortMenu.Items.Add((New-Object System.Windows.Controls.Separator)) | Out-Null

    & $addSortOption "Date modified (Newest)" "Date" $false "#F59E0B"
    & $addSortOption "Date modified (Oldest)" "Date" $true "#F59E0B"
    $sortMenu.Items.Add((New-Object System.Windows.Controls.Separator)) | Out-Null

    & $addSortOption "Size (Largest first)" "Size" $false "#A78BFA"
    & $addSortOption "Size (Smallest first)" "Size" $true "#A78BFA"
    $sortMenu.Items.Add((New-Object System.Windows.Controls.Separator)) | Out-Null

    # File Type Option
    $isTypeActive = ($Script:CurrentSortField -eq "Type")
    $typeGlyph = if ($isTypeActive) { [char]0xE73E } else { [char]0xE7C3 }
    $typeColor = if ($isTypeActive) { "#38BDF8" } else { "#5A5A66" }
    $miType = New-DarkMenuItem "Type (File extension)" $typeGlyph $typeColor { Set-ExplorerSortMode "Type" $true }
    if ($isTypeActive) {
        $miType.FontWeight = [System.Windows.FontWeights]::Bold
        $miType.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#38BDF8")
    }
    $sortMenu.Items.Add($miType) | Out-Null

    $sortMenu.IsOpen = $true
}

if ($BtnToggleSort) {
    # Left-click opens the sort menu directly so user can choose
    $BtnToggleSort.add_Click({ Show-ExplorerSortMenu })

    # Disable right-click context menu completely
    $BtnToggleSort.ContextMenu = $null
    $BtnToggleSort.add_PreviewMouseRightButtonDown({ param($s, $e) $e.Handled = $true })
    $BtnToggleSort.add_PreviewMouseRightButtonUp({ param($s, $e) $e.Handled = $true })
}

if ($BtnEditTextPreview) {
    $BtnEditTextPreview.add_Click({ Enter-PreviewEditMode })
}

if ($BtnSaveTextPreview) {
    $BtnSaveTextPreview.add_Click({ Save-PreviewTextContent })
}

if ($BtnCancelEditTextPreview) {
    $BtnCancelEditTextPreview.add_Click({ Exit-PreviewEditMode $true })
}

if ($TxtPreviewContent) {
    $TxtPreviewContent.add_TextChanged({
        $lines = $TxtPreviewContent.Document.Blocks.Count
        if ($TxtCodeLineCount -and $lines -gt 0) {
            $TxtCodeLineCount.Text = "$lines lines"
        }
    })
}

if ($BtnHidePreviewPane) {
    $BtnHidePreviewPane.add_Click({ Hide-PreviewPane })
}



# 6. Header Logo Click -> Return to Files
if ($BtnHeaderLogo) {
    $BtnHeaderLogo.add_MouseLeftButtonUp({
        Show-ExplorerFilesView
    })
}

# Startup Initialization
Load-PinnedFolders
Update-QuickAccessPinnedButtons

if ($PanelQuickAccessCustom) {
    $PanelQuickAccessCustom.Add_DragOver({
        param($s, $e)
        if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
            $e.Effects = [System.Windows.DragDropEffects]::Link
            $e.Handled = $true
        }
    })
    $PanelQuickAccessCustom.Add_Drop({
        param($s, $e)
        if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
            $droppedItems = $e.Data.GetData([System.Windows.DataFormats]::FileDrop)
            foreach ($item in $droppedItems) {
                if (Test-Path -LiteralPath $item -PathType Container) {
                    Pin-ExplorerQuickAccessPath $item
                }
            }
            $e.Handled = $true
        }
    })
}

if ($BtnNewWorkspaceTab) {
    $BtnNewWorkspaceTab.add_Click({ Add-WorkspaceTab })
}

if ($BtnToggleHyprlandTiling) {
    $BtnToggleHyprlandTiling.add_Click({ Toggle-HyprlandTilingMode })
}

Update-ExplorerDriveButtons
[void](Add-WorkspaceTab $Script:ExplorerCurrentPath $true)

# Auto-check for updates on launch
$Window.Add_Loaded({
    Check-GitHubAppUpdateAsync $false
})

# Show Window
[void]$Window.ShowDialog()
