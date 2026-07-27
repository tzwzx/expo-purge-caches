# expo-purge-caches

[English](https://github.com/tzwzx/expo-purge-caches/blob/main/README.md) | 日本語

**Expo / React Native のビルドキャッシュを一掃し、まっさらな状態からリビルドできるようにする CLI ツールです。** 🧹

「依存関係を更新したのに変更が反映されない」「キャッシュを消しても `Unable to resolve module` が解消しない」「古い生成物のせいで Xcode のビルドが失敗する」——こうしたキャッシュ起因の手詰まりに陥ったとき、このツールが関連するキャッシュをまとめて削除し、すべてを一からリビルドできる状態に戻します。

実体は単一のシェルスクリプト [bin/purge-build-caches.sh](bin/purge-build-caches.sh) で、`expo-purge-caches` コマンドとして公開されています。

---

## ✨ 何をするツール？

デフォルトでは、`expo-purge-caches` は**削除しても安全で、プロジェクトに閉じたもの**（およびそれに紐づくユーザー単位の Metro / Watchman の状態）だけを対象とします。

1. プロジェクト内のローカルなビルド生成物（`ios` / `android` / `.expo` / `.gradle` / `node_modules/.cache`）——`ios` / `android` については[安全性チェック](#-安全性チェック)あり
2. Metro バンドラーのキャッシュ（`$TMPDIR/metro-*`、`$TMPDIR/haste-map-*`）
3. Watchman の watch（`watchman watch-del-all`）

**`--deep`** フラグを付けると、さらに**すべてのプロジェクトで共有されるマシン全体のキャッシュ**も（確認プロンプトのうえで）削除します。

4. Xcode のキャッシュ（`~/Library/Developer/Xcode/DerivedData`、`~/Library/Caches/com.apple.dt.Xcode`）
5. iOS シミュレーターのキャッシュ（`~/Library/Developer/CoreSimulator/Caches`）
6. CocoaPods のキャッシュ（`pod cache clean --all`、`~/Library/Caches/CocoaPods`）
7. Swift Package Manager のキャッシュ（`~/Library/Caches/org.swift.swiftpm`）
8. Gradle のキャッシュ（`~/.gradle/caches`）

マシン全体のキャッシュを削除しても何かが壊れることはありませんが、キャッシュが再生成されるまでは**他の**プロジェクトの次回ビルドが遅くなります。オプトインになっているのはそのためです。

---

## 📦 動作要件

| 項目 | 内容 |
| --- | --- |
| OS | **macOS または Linux**（Xcode / シミュレーター / CocoaPods の処理は macOS でのみ実行され、それ以外ではスキップされます） |
| 必須 | Node.js（`npx` での実行に使用）、Bash |
| 任意 | Watchman、CocoaPods（未インストールなら該当処理はスキップされます） |

> 📝 Windows は未対応です（パッケージが `"os": ["darwin", "linux"]` を宣言しています）。

---

## 🚀 使い方

### npx で直接実行する（インストール不要）

```bash
# safe, project-scoped purge
npx expo-purge-caches

# also purge machine-wide caches (Xcode, Simulator, CocoaPods, Gradle, SwiftPM)
npx expo-purge-caches --deep

# preview what would be deleted, without deleting anything
npx expo-purge-caches --deep --dry-run
```

> ⚠️ **Expo / React Native プロジェクトのルート**で実行してください。カレントディレクトリに `expo` または `react-native` を依存に持つ `package.json` がない場合、コマンドは実行を拒否するので、うっかり別の場所で実行しても無害です。

### オプション

| オプション | 説明 |
| --- | --- |
| `--deep` | 全プロジェクトで共有されるマシン全体のキャッシュも削除する（確認あり） |
| `--dry-run` | 削除対象をすべて表示するだけで、実際には削除しない |
| `-y`, `--yes` | 確認プロンプトをスキップする（CI / npm スクリプト向け） |
| `--version` | バージョンを表示する |
| `-h`, `--help` | ヘルプを表示する |

### グローバルにインストールする

```bash
npm install -g @tzwzx/expo-purge-caches

# afterwards you can run it from anywhere by name
expo-purge-caches
```

### プロジェクトの npm スクリプトに組み込む

`package.json` に登録しておくと、チームで共有しやすくなります。

```jsonc
{
  "scripts": {
    "clean": "expo-purge-caches",
    "clean:deep": "expo-purge-caches --deep --yes"
  }
}
```

```bash
npm run clean
```

---

## 🛟 安全性チェック

このスクリプトは、何かを削除する前に意図的なまでに慎重に振る舞います。

- **プロジェクトの検証** —— カレントディレクトリに `expo` または `react-native` を依存として宣言した `package.json` がなければ、実行を拒否します。誤ったディレクトリで実行しても何も起こりません。
- **`ios` / `android` の保護** —— これらのディレクトリは **git で管理されていない場合にのみ**削除されます（つまり、[Continuous Native Generation](https://docs.expo.dev/workflow/continuous-native-generation/) のように生成物である場合です）。git で管理されている場合——通常は手書きのネイティブコードがあることを意味します——は、削除せずに**警告を出してスキップ**します。そもそも git リポジトリでない場合は、確認を求められます。
- **マシン全体のキャッシュはオプトイン** —— `--deep` を付けない限り、プロジェクト外のもの（Metro の一時ファイルと Watchman の watch を除く）には一切触れません。さらに `--deep` は事前に確認を求めます。
- **`--dry-run`** —— 削除されるパスをすべて事前に確認できます。
- **ツールが無くても壊れない** —— Watchman / CocoaPods の処理は、それらが未インストールならスキップされます。

---

## 🧹 削除されるもの（詳細）

### 1. ローカルなビルド生成物（プロジェクト内）

| 対象 | 何のファイルか | 削除する理由 |
| --- | --- | --- |
| `ios` / `android` | ネイティブプロジェクトのディレクトリ | 古いネイティブのビルド設定 / 出力をリセットするため。git で管理されていない場合のみ削除（`npx expo prebuild` で再生成可能） |
| `.expo` | Expo のローカルキャッシュ / 一時設定 | 開発サーバー関連の古いキャッシュを削除するため |
| `.gradle` | プロジェクト単位の Gradle キャッシュ | 古い Gradle の設定状態を削除するため |
| `node_modules/.cache` | 各種ツールのキャッシュディレクトリ | Babel / Metro などが残したキャッシュを削除するため（`node_modules` 全体は削除**されません**） |

### 2. Metro バンドラーのキャッシュ

```bash
rm -rf "$TMPDIR"/metro-* "$TMPDIR"/haste-map-*
```

Metro はキャッシュを、Node.js が報告する OS の一時ディレクトリ（`os.tmpdir()`）に書き込みます。macOS ではこれは `/tmp` **ではなく** `$TMPDIR`（`/var/folders/...` 以下のどこか）です。これは [Expo 公式のキャッシュクリア手順](https://docs.expo.dev/troubleshooting/clear-cache-macos-linux/)に沿っています。

| 対象 | 何のファイルか |
| --- | --- |
| `$TMPDIR/metro-*` | Metro のトランスフォーマーキャッシュ（`metro-cache`）、新しめの Metro のファイルマップキャッシュ（`metro-file-map-*`）など |
| `$TMPDIR/haste-map-*` | ファイルマップキャッシュ（古い Metro のもの） |

### 3. Watchman

```bash
watchman watch-del-all
```

すべての watch を解除し、Watchman のファイル監視状態をリセットします。Watchman が未インストールならスキップされます。

### 4. マシン全体のキャッシュ（`--deep` 指定時のみ）

| 対象 | 何のファイルか |
| --- | --- |
| `~/Library/Developer/Xcode/DerivedData` | Xcode の中間ビルド出力 / インデックス |
| `~/Library/Caches/com.apple.dt.Xcode` | Xcode アプリ自体のキャッシュ |
| `~/Library/Developer/CoreSimulator/Caches` | iOS シミュレーターのキャッシュ |
| `pod cache clean --all` + `~/Library/Caches/CocoaPods` | ダウンロード済み Pod のキャッシュ |
| `~/Library/Caches/org.swift.swiftpm` | Swift Package Manager のダウンロード |
| `~/.gradle/caches` | Gradle のグローバルな依存関係 / ビルドキャッシュ |

---

## 🖥 出力例

```text
$ npx expo-purge-caches
Purging build caches...
▸ Removing local build artifacts...
  ✓ removed: ios
  ✓ removed: android
  ✓ removed: .expo
  ✓ removed: node_modules/.cache
▸ Removing Metro cache...
  ✓ removed: /var/folders/xx/.../T/metro-cache
▸ Resetting Watchman watches...
  ▹ running: watchman watch-del-all
✔ Done.
```

---

## ⚠️ 注意事項（実行前にお読みください）

- **`ios` / `android` ディレクトリは、git で管理されていなければ削除されます。**
  これは `npx expo prebuild`（Continuous Native Generation）で再生成できることを前提としています。git で管理されているディレクトリは自動的にスキップされますが、何らかの事情で手書きのネイティブコードを git 管理外に置いている場合は、事前にコミットするかバックアップを取ってください。

- **`--deep` は他のプロジェクトにも影響します。**
  Xcode の DerivedData、シミュレーターのキャッシュ、CocoaPods / Gradle / SwiftPM のキャッシュはグローバルなものです。他のプロジェクトの次回ビルドは遅くなったり、依存関係を再ダウンロードしたりします（壊れるわけではなく、再生成に時間がかかるだけです）。

- **カレントディレクトリを対象に動作します。**
  必ず対象プロジェクトのルートで実行してください。組み込みのプロジェクト検証により、Expo / React Native プロジェクトに見えない場所では実行を拒否します。

---

## 🔄 実行後のクリーンリビルド手順（参考）

キャッシュを削除したら、ビルドの前に依存関係とネイティブプロジェクトを作り直してください。以下は典型的な例です（スクリプト自体はこれらを**実行しません**）。

```bash
# 1. Reinstall dependencies
npm install            # or yarn / bun install

# 2. Regenerate native projects (for Continuous Native Generation)
npx expo prebuild --clean

# 3. Start the dev server with cache clearing
npx expo start --clear

# 4. Build natively and run
npx expo run:ios
npx expo run:android
```

---

## 💡 こんなときに

- 依存関係やネイティブモジュールを更新したのに、変更が反映されない
- `Unable to resolve module ...` のような解決エラーが、通常のキャッシュクリアでは解消しない
- 古い中間生成物のせいで Xcode のビルドが失敗する
- 問題の切り分けとして、とにかく一度まっさらな状態からクリーンリビルドしたい

---

## 📄 ライセンス

[MIT](LICENSE)
