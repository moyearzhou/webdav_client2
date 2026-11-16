# webdav_client

A dart WebDAV client library(`support null-safety`), **use [dio](https://github.com/flutterchina/dio) as http client**.

This repository is the ZotPaper fork of [flymzero/webdav_client](https://github.com/flymzero/webdav_client), distributed through the private ZotPaper pub registry under the original BSD 3-Clause [license](LICENSE).

## ZotPaper installation

Configure your registry token once (enter it at the prompt):

```sh
dart pub token add https://pub.zotpaper.cn
```

Use an explicit hosted source so the ZotPaper fork is selected:

```yaml
dependencies:
  webdav_client:
    hosted: https://pub.zotpaper.cn
    version: ^1.2.3
```

Version `1.2.3` preserves the runtime code from Git tag `v-0.1.1`: `isExists()` via HEAD, 301/302 redirects, and byte-upload compatibility when a server rejects parent-directory creation. The package version is independent of ZotPaper app versions; its Git tag is `v-1.2.3`.

Run `dart test` for the local HTTP regression suite; no external WebDAV server or credentials are needed.

## Main features

* support ``Basic/Digest`` authentication
* [common settings](#common-settings)
* [read dir](#read-all-files-in-a-folder)
* [make dir](#create-folder)
* [delete](#remove-a-folder-or-file)
* [rename](#rename-a-folder-or-file)
* [copy](#copy-a-file-/-folder-from-A-to-B)
* [download file](#download-file)
* [upload file](#upload-file)
* [cancel request](#cancel-request)
---

## web support

see [stackoverflow](https://stackoverflow.com/questions/65630743/how-to-solve-flutter-web-api-cors-error-only-with-dart-code) for CORSB problems needing attention

![web](https://raw.githubusercontent.com/flymzero/webdav_client/main/images/1.png)
---

## Usage

First of all you should create `client` instance using `newClient()` function:
```dart
var client = newClient(
    'http://localhost:6688/',
    user: 'flyzero',
    password: '123456',
    debug: true,
  );
```

### Common settings
```dart
    // Set the public request headers
    client.setHeaders({'accept-charset': 'utf-8'});

    // Set the connection server timeout time in milliseconds.
    client.setConnectTimeout(8000);

    // Set send data timeout time in milliseconds.
    client.setSendTimeout(8000);

    // Set transfer data time in milliseconds.
    client.setReceiveTimeout(8000);

    // Test whether the service can connect
    try {
      await client.ping();
    } catch (e) {
      print('$e');
    }
```

### Read all files in a folder
```dart
    var list = await client.readDir('/');
    list.forEach((f) {
        print('${f.name} ${f.path}');
      });

    // can sub folder
    var list2 = await client.readDir('/sub/sub/folder');
    list2.forEach((f) {
        print('${f.name} ${f.path}');
      });
    
```

### Create folder
```dart
    await client.mkdir('/新建文件夹');

    // Recursively create folders
    await client.mkdirAll('/new folder/new folder2');
```

### Remove a folder or file
> If you remove the folder, some webdav services require a '/' at the end of the path.
```dart
    // Delete folder
    await client.remove('/new folder/new folder2/');

    // Delete file
    await client.remove('/new folder/新建文本文档.txt');
```

### Rename a folder or file
> If you rename the folder, some webdav services require a '/' at the end of the path.
```dart
    // Rename folder
    await client.rename('/新建文件夹/', '/新建文件夹2/', true);

    // Rename file
    await client.rename('/新建文件夹2/test.dart', '/新建文件夹2/test2.dart', true);
```

### Copy a file / folder from A to B
> If copied the folder (A > B), it will copy all the contents of folder A to folder B.

> Some webdav services have been tested and found to delete the original contents of the B folder!!!
```dart
    // Copy all the contents of folderA to folder B
    await client.copy('/folder/folderA/', '/folder/folderB/', true);

    // Copy file
    await client.copy('/folder/aa.png', '/folder/bb.png', true);
```

### Download file
```dart
    // download bytes
    await client.read('/folder/folder/openvpn.exe', onProgress: (c, t) {
        print(c / t);
      });

    // download 2 local file with stream 
    await client.read2File(
          '/folder/vpn.exe', 'C:/Users/xxx/vpn2.exe', onProgress: (c, t) {
        print(c / t);
      });
```

### Upload file
```dart
    // upload local file 2 remote file with stream
    CancelToken c = CancelToken();
    await client.writeFromFile(
        'C:/Users/xxx/vpn.exe', '/f/vpn2.exe', onProgress: (c, t) {
        print(c / t);
      }, cancelToken: c);
```

### Cancel request
```dart
    CancelToken cancel = CancelToken();

    // Supports most methods
    client.mkdir('/新建文件夹', cancel)
    .catchError((err) {
      prints(err.toString());
    });

    // in other
    cancel.cancel('reason')
```
