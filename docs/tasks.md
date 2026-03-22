# Tasks

## Todo

- [ ] Advancedの移植（pass, with, andThen）
- [ ] Helper functions for special situationの移植（list, listOf, array, arrayOf）
- [ ] READMEを書く
- [ ] バリデーションで使うために必要な関数をリストアップし、追加する
- [ ] バリデーションで使えるように書き換える
- [ ] 関数名やシグネチャをMoonBitの標準ライブラリに合わせる
  - [ ] パイプラインの使いやすさを考えて、引数の順番を調整する

## In-Progress

## Done

- [x] `-- Advanced`の手前まで移植

## メモ

型は`Decoder`と`Validator`がある。`Validator`は`Decoder`の出力がないバージョン。

プリミティブなデコーダーは`int`、`float`がある。`string`とかはないんだろうか。

プリミティブなバリデーターは`minBound`、`minBoundWith`、`minLength`とその`max`バージョン。`minBoundWith`はなんだろう？
