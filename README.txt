README
------

qlZipInfo v1.2.4

Homepage:

    https://github.com/srirangav/qlZipInfo

Overview:

    qlZipInfo is a QuickLook generator for zip, jar, tar,
    tar.gz (.tgz), tar.bz2 (.tbz2/.tbz), tar.Z (.tZ), xar
    (.xar, .pkg), debian (.deb), Redhat Package Manager
    (.rpm), 7zip (.7z), xz, Microsoft cabinet (.cab), gzip
    (.gz), lha, Binhex 4.0 (.hqx), and Stuffit (.sit)
    archives and ISO9660 (.iso, .cdr, .toast) images.

    qlZipInfo relies on libarchive (https://libarchive.org/).

    Information for each file in an archive is displayed in
    the following format:

        Icon | Filename | Size | Date Modified

    A folder icon is shown for folders / directories, a file
    icon is shown for regular files, and a lock icon is shown
    for encypted files.  In addition, for BinHex 4.0 archives,
    a package icon is shown if the file stored in the archive
    is a Stuffit archive and an application icon is shown if
    the file stored in the archive is an application.

    After listing information for all the files in an archive,
    a summary rows is shown with the number of files in the
    archive, the archive's total uncompressed size, the
    archive's total compressed size and the % compression.

    For BinHex 4.0 files, the date modified and the summary
    row are omitted. Instead the MacOS type and creator are
    shown.

Install:

    1. Create the directory ~/Library/QuickLook if it doesn't
       exist

    2. Copy qlZipInfo.qlgenerator to ~/Library/QuickLook

    3. Restart QuickLook:

       /usr/bin/qlmanage -r
       /usr/bin/qlmanage -r cache

    4. Wait a minute or two for QuickLook to properly load
       or reload qlZipInfo.qlgenerator

    Homebrew (https://brew.sh/) users can install qlZipInfo
    using `iloveitaly/tap/qlzipinfo`.

Supported MacOSX versions:

    v. 1.2.0 and onwards - 10.13+
    v. 1.0.9 - 1.1.11    - 10.9+
    v. 1.0.8 and earlier - 10.6+

Known Issues:

    1. If WinZip is installed (for example, as part of Roxio
       Toast), this quicklook generator will not produce a
       preview for zip files because Quicklook always prefers
       generators that are included in an application and
       there is no way to override this behavior without
       editing WinZip.  Similarly, if Suspicious Package is
       installed, this quicklook generator will not produce a
       preview for .pkg files. See:

       https://stackoverflow.com/questions/11705425

    2. Unix Compress'ed tar files with the extension .tz or
       .tZ cannot be reliabily detected and previewed

    3. InstallSheild CAB files are not currently supported

    4. Only BinHex 4.0 files are supported

    5. Stuffit 5 files are not currently supported

History:

    v1.2.4  - update to libarchive v.3.7.1 and update lzma
              headers from xz v.5.4.3
    v1.2.3  - update to libarchive v.3.7.0 and Google Toolbox
              for Mac v.3.0.0
    v1.2.2  - add support for ePub files
    v1.2.1  - update to libarchive v.3.6.2
    v1.2.0  - updates for Xcode 14.1, add instructions for
              installation through Homebrew
    v1.1.11 - add support for some Stuffit files
    v1.1.10 - update to libarchive v.3.6.1 and lzma headers from
              xz v.5.2.5
    v1.1.9  - add support for (some?) CD/DVD images created by
              Roxio Toast
    v1.1.8  - upgrade to libarchive v.3.6.0
    v1.1.7  - add support for BinHex 4.0 files
    v1.1.6  - fix to detect .tgz files as tar-gzip'ed archives and
              .tbz files as tar-bzip2'ed archives, disable preview
              of 1Password backups
    v1.1.5  - upgrade to libarchive v.3.5.2, add support for
              uuencoded archives and rpm files
    v1.1.4  - modularize preview generation, add total compressed
              size to the summary row
    v1.1.3  - add support for Microsoft CAB files and gzip'ed
              archives of a single file
    v1.1.2  - (partially?) fix listing non-ASCII filenames
    v1.1.1  - add support for xar / pkg, debian (.deb), 7zip (.7z),
              xz, and lha archives and ISO9660 images
    v1.1.0  - switch to libarchive and add support for .tar,
              .tar.gz, .tar.bz2, and tar.Z files
    v1.0.15 - show a lock icon for encrypted files
    v1.0.14 - fixes to make darkmode and light mode better match
              BigSur's Finder
    v1.0.13 - make sure days and months are zero prefixed
    v1.0.12 - increase size used to display the compressed file
              size; disable showing the compression method
    v1.0.11 - add support for zip files with non-UTF8 filenames
    v1.0.10 - add darkmode support
    v1.0.9  - build on Big Sur (11.x)
    v1.0.8  - add support for some 1Password backups
    v1.0.7  - update to Minizip 1.2, show compression method
    v1.0.6  - updates for Xcode 10.2
    v1.0.5  - internal updates
    v1.0.4  - internal updates
    v1.0.3  - localize the date, change compression reporting, and
              escape any HTML characters in file / folder names
    v1.0.2  - add icons, display file compression, size in B, KB,
              MB, etc.
    v1.0.1  - initial release

License:

    Please see LICENSE.txt
