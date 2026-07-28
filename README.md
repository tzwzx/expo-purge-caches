# @tzwzx/expo-purge-caches

Expo アプリ群で共有する、**ビルドキャッシュ一括削除スクリプト**。

「依存を更新したのに反映されない」「キャッシュを消しても `Unable to resolve module` が消えない」
「古い中間生成物のせいで Xcode のビルドが通らない」といった、
キャッシュ起因で詰まったときにクリーンな状態から作り直すために使う。

実体は [`bin/purge-build-caches.sh`](bin/purge-build-caches.sh) 1本のシェルスクリプトで、
`expo-purge-caches` コマンドとして公開している。

## 消費側での使われ方

各アプリの devDependencies に Git URL で入れ、**`-y --deep` 固定の npm script 1本**から呼ぶ。
この呼び出し方以外は現状どのアプリでも使っていない。

```jsonc
// 各アプリの package.json
"devDependencies": {
  "@tzwzx/expo-purge-caches": "github:tzwzx/expo-purge-caches"
},
"scripts": {
  "purge-caches": "expo-purge-caches -y --deep"
}
```

> ⚠️ **npm には公開していない**（`@tzwzx/expo-purge-caches` はレジストリに存在しない）。
> `npx expo-purge-caches` や `npm install -g` は動かないので、案内に書かないこと。
>
> ⚠️ Git URL 依存では `package.json` の `files` が効かず、**リポジトリ全体が node_modules に入る**。
> 配布物を絞る目的で `files` を頼らないこと。

## 仕様

### 既定（引数なし）— プロジェクトに閉じた削除

| 対象 | 中身 |
| --- | --- |
| `ios` / `android` | ネイティブプロジェクト。**git 管理下にない場合のみ**削除（下記の安全機構を参照） |
| `.expo` | Expo のローカルキャッシュ / 一時設定 |
| `.gradle` | プロジェクト単位の Gradle キャッシュ |
| `node_modules/.cache` | Babel / Metro 等が残すキャッシュ（`node_modules` 全体は消さない） |
| `$TMPDIR/metro-*`, `$TMPDIR/haste-map-*` | Metro のキャッシュ。**`/tmp` ではなく `os.tmpdir()`**（macOS では `/var/folders/...`）に置かれる |
| `watchman watch-del-all` | Watchman の監視状態をリセット（未インストールならスキップ） |

### `--deep` — マシン全体の共有キャッシュも削除

確認プロンプトの後に追加で消す。壊れはしないが、**他のプロジェクトの次回ビルドが遅くなる**ため opt-in。

`~/Library/Developer/Xcode/DerivedData` / `~/Library/Caches/com.apple.dt.Xcode` /
`~/Library/Developer/CoreSimulator/Caches` / `pod cache clean --all` + `~/Library/Caches/CocoaPods` /
`~/Library/Caches/org.swift.swiftpm` / `~/.gradle/caches`

### オプション

| オプション | 説明 |
| --- | --- |
| `--deep` | マシン全体の共有キャッシュも削除する（確認プロンプトあり） |
| `--dry-run` | 削除せず、消す対象を表示するだけ |
| `-y`, `--yes` | 確認プロンプトを飛ばす（npm script から呼ぶため必須） |
| `--version` | バージョン表示 |
| `-h`, `--help` | ヘルプ表示 |

## 変更するときに壊してはいけない安全機構

このスクリプトは**破壊的な操作をする**ため、以下は仕様として維持すること。

- **プロジェクト検証** — カレントディレクトリの `package.json` が `expo` または `react-native` に
  依存していなければ実行を拒否する。別ディレクトリで誤爆しても無害であることを保証している
- **`ios` / `android` の保護** — **git 管理下にない場合のみ**削除する
  （= Continuous Native Generation の生成物で `expo prebuild` で復元できる）。
  git 管理下＝手書きのネイティブコードがある可能性が高いので、削除せず警告してスキップする。
  git リポジトリでない場合は確認を取る
- **マシン全体のキャッシュは `--deep` の時だけ**触る
- **ツール未インストールで落とさない** — Watchman / CocoaPods は無ければスキップ

`package.json` の `"os": ["darwin", "linux"]` により Windows は対象外。
Xcode / Simulator / CocoaPods 関連は macOS 以外ではスキップされる。

## 変更したときの確認

```bash
# 消す対象だけを確認する（実際には消さない）
bash bin/purge-build-caches.sh --deep --dry-run

# 安全機構が効いているか: Expo でないディレクトリでは実行を拒否するはず
cd /tmp && bash <このリポ>/bin/purge-build-caches.sh
```

各アプリへの反映は `bun update @tzwzx/expo-purge-caches`。

## 削除後のクリーンビルド手順（参考・スクリプトはここまでやらない）

```bash
bun install
bunx expo prebuild --clean
bunx expo start --clear
bunx expo run:ios
```

## License

[MIT](LICENSE)
