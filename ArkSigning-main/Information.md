
## Compile on macOS:

```bash
brew install openssl
```
and then (attention to replace your openssl version)
```bash
g++ *.cpp common/*.cpp -lcrypto -I/usr/local/Cellar/openssl@1.1/1.1.1k/include -L/usr/local/Cellar/openssl@1.1/1.1.1k/lib -O3 -o arksigning
```

## Compile on Linux:

#### Ubuntu:


```bash
sudo apt-get install git
git clone https://github.com/nabzclan-reborn/ArkSigning.git; cd arksigning && chmod +x INSTALL.sh &&
./INSTALL.sh
```

#### CentOS7:


```bash
yum install git 
git clone https://github.com/nabzclan-reborn/ArkSigning.git; cd arksigning && chmod +x INSTALL.sh &&
./INSTALL.sh
```


#### Compile on Windows/MingW:

Note:  These instructions describe how to cross-compile for Windows from
Linux.  I haven't tested these steps compiling for Windows from Windows,
but it should mostly work.

These instructions assume that mman-win32, arksigning, and openssl are all
sibling directories

1.  Install MingW
```bash
apt-get install mingw-w64

```
2. Build mman-win32

```bash
git clone git@github.com:witwall/mman-win32
cd mman-win32
./configure --cross-prefix=x86_64-w64-mingw32-
make
```

3.  Build openssl
```
git clone github.com:openssl/openssl
cd openssl
git checkout OpenSSL_1_0_2s
./Configure --cross-compile-prefix=x86_64-w64-mingw32- mingw64
make

```

4. Build arksigning
```bash
x86_64-w64-mingw32-g++  \
*.cpp common/*.cpp -o arksigning.exe  \
-lcrypto -I../mman-win32  \
-std=c++11  -I../openssl/include/  \
-DWINDOWS -L../openssl  \
-L../mman-win32  \
-lmman -lgdi32  \
-m64 -static -static-libgcc -lws2_32
```

## Optional Compile:

#### Compile it yourserlf:
1. Install the required dependencies accodring to your Os. 
2. Clone arksigning repositorie.

> Recommended  
> 
```bash
mkdir build; cd build
cmake ..
make
```
or

> Optional
> 
```bash
g++ *.cpp common/*.cpp -std=gnu++11 -lcrypto -O3 -o arksigning
```

## Compile arksigning xmake:

If you have [xmake](https://xmake.io) installed, you can use xmake to quickly compile and run it.

#### Build

```console
xmake
```

#### Run

```console
xmake run arksigning [-options] [-k privkey.pem] [-m dev.prov] [-o output.ipa] file|folder
```

#### Install

```console
xmake install
```

#### Get arksigning binary

```console
xmake install -o outputdir
```

binary: `outputdir/bin/arksigning`

## Compile using Docker:

1. Build:
```
docker build -t arksigning https://github.com/nabzclan-reborn/ArkSigning.git
```

2. Run:

*Mount current directory (stored in $PWD) to container and set WORKDIR to it:*
```
docker run -v "$PWD:$PWD" -w "$PWD" arksigning -k privkey.pem -m dev.prov -o output.ipa -z 9 demo.ipa
```

*If input files are outside current folder, you will need to mount different folder:*
```
docker run -v "/source/input:/target/input" -w "/target/input" arksigning -k privkey.pem -m dev.prov -o output.ipa -z 9 demo.ipa
```

3. Extract the arksigning executable

*You can extract the static linked arksigning executable from the container image and deploy it to other server:*
```
docker run -v $PWD:/out --rm --entrypoint /bin/cp arksigning arksigning /out

```
<br>


## arksigning usage:
I have already tested on macOS and Linux, but you also need **unzip** and **zip** command installed.

```bash
Usage: arksigning [-options] [-k privkey.pem] [-m dev.prov] [-o output.ipa] file|folder

options:
-k, --pkey              Path to private key or p12 file. (PEM or DER format)
-m, --prov              Path to mobile provisioning profile.
-c, --cert              Path to certificate file. (PEM or DER format)
-d, --debug             Generate debug output files. (.arksigning_debug folder)
-f, --force             Force sign without cache when signing folder.
-o, --output            Path to output ipa file.
-p, --password          Password for private key or p12 file.
-b, --bundle_id         New bundle id to change.
-n, --bundle_name       New bundle name to change.
-I, --info             Output app information in JSON format, including app icon in base64.
-r, --bundle_version    New bundle version to change.
-e, --entitlements      New entitlements to change.
-z, --zip_level         Compressed level when output the ipa file. (0-9)
-l, --dylib             Path to inject dylib file.
                        Use -l multiple time to inject multiple dylib files at once.
-w, --weak              Inject dylib as LC_LOAD_WEAK_DYLIB.
-i, --install           Install ipa file using ideviceinstaller command for test.
-q, --quiet             Quiet operation.
-E, --no-embed-profile  Don't generate embedded mobile provision.
-v, --version           Shows version.
-h, --help              Shows help (this message).

Bulk signing options:
-B, --bulk              Enable bulk signing mode.
--inputfolder           Folder containing unsigned apps to process.
--outputfolder          Destination folder for signed apps.
--parallel              Enable parallel processing with optional thread count.
--base-url              Base URL used to generate OTA link (e.g., https://signer.vip/signed/)
```

1. Show mach-o and codesignature segment info.
```bash
./arksigning demo.app/execute
```

2. Sign ipa with private key and mobileprovisioning file.
```bash
./arksigning -k privkey.pem -m dev.prov -o output.ipa -z 9 demo.ipa
```

3. Sign folder with p12 and mobileprovisioning file (using cache).
```bash
./arksigning -k dev.p12 -p 123 -m dev.prov -o output.ipa demo.app
```

4. Sign folder with p12 and mobileprovisioning file (without cache).
```bash
./arksigning -f -k dev.p12 -p 123 -m dev.prov -o output.ipa demo.app
```

5. Inject dylib into ipa and re-sign.
```bash
./arksigning -k dev.p12 -p 123 -m dev.prov -o output.ipa -l demo.dylib demo.ipa
```

6. Change bundle id and bundle name
```bash
./arksigning -k dev.p12 -p 123 -m dev.prov -o output.ipa -b 'com.tree.new.bee' -n 'TreeNewBee' demo.ipa
```

7. Inject dylib(LC_LOAD_DYLIB) into mach-o file.
```bash
./arksigning -l "@executable_path/demo.dylib" demo.app/execute
```

8. Inject dylib(LC_LOAD_WEAK_DYLIB) into mach-o file.
```bash
./arksigning -w -l "@executable_path/demo.dylib" demo.app/execute
```

9. Don't generate embedded mobile provision.
```bash
./arksigning -k -E p12file.p12 -m mpfile.mobileprovison -o output.ipa -z 9 demo.ipa
```

10. Show app info with app icon in base64 format.
```bash
./arksigning --info app.ipa
```

11. Bulk sign all apps in a folder.
```bash
./arksigning --bulk --inputfolder ./unsigned_apps --outputfolder ./signed_apps -k dev.p12 -p 123 -m dev.prov
```

12. Bulk sign with parallel processing (auto-detect thread count).
```bash
./arksigning --bulk --inputfolder ./unsigned_apps --outputfolder ./signed_apps -k dev.p12 -p 123 -m dev.prov --parallel
```

13. Bulk sign with specified thread count.
```bash
./arksigning --bulk --inputfolder ./unsigned_apps --outputfolder ./signed_apps -k dev.p12 -p 123 -m dev.prov --parallel 4
```
14. Base URL used to generate OTA link
```bash
./signervip --base-url\t\tBase URL used to generate OTA link (e.g., https://signer.vip/signed/)\n");
```
## How to sign quickly?

You can unzip the ipa file at first, and then using arksigning to sign folder with assets.
At the first time of sign, arksigning will perform the complete signing and cache the signed info into *.arksigning_cache* dir at the current path.
When you re-sign the folder with other assets next time, arksigning will use the cache to accelerate the operation. Extremely fast! You can have a try!

For bulk signing of multiple apps, use the `--bulk` mode with `--parallel` for maximum performance. This allows processing multiple apps simultaneously using multithreading.

## Changelog
### v0.6.1 (2025-05-01)
NEW — Adds base URL used for OTA .plist generation
Automatically generates a plist file and logs an itms-services:// install link

### v0.6 (2025-04-26)
- Added app icon retrieval in base64 format when using `--info` flag to retrive app info
- Implemented bulk signing feature with `--bulk`
- Added parallel processing support with `--parallel` option

### v0.5
- Added support for removing embedded.mobileprovision with `-E` flag

## Credits
 -**SignerVIP** ([Website](https://signer.vip))
  
- **NabzClan** ([Website](https://nabzclan.vip))
  - Dev Team
- **arinawzad** ([Github](https://github.com/arinawzad))
  - Added support for removing embedded.mobileprovision
- **zhlynn** ([Github](https://github.com/zhlynn))
  - Original Creator
