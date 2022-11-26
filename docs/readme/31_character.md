
ゲームの要素とその実現方法について

<[前のページに戻る](./21_commit-reveal.md)>

 < [HOMEに戻る](../../README.md)   >
___
# キャラクター (PLM Token)
![ガチャで引かれることによって、OpenSea(テストネットワーク版)上でもキャラの情報が閲覧可能となっている。](../imgs/opensea.png)

ガチャで引かれることによって、OpenSea(テストネットワーク版)上でもキャラの情報が閲覧可能となっている。


## 概要
PLMTokenはERC721トークンとして実装されています。

プレイヤーは所持するキャラクターを育成し、バトルで使用することができます。

キャラクターはレベル、属性、特性、絆レベルを持ちます。

### レベル
キャラクターの基礎攻撃力を表しており、PLMCoinをゲームコントラクトに支払うことでレベルアップすることができます。

### 属性

自分と攻撃相手の属性の組み合わせによって有利だとダメージが20%増加、不利だと20%減少します。

### 特性

キャラクターごとに持つ特殊能力（いわゆるパッシブスキル）です。それぞれのキャラクターが1つだけ持っており、属性相性とは別にダメージ計算やその他のバトル要素に影響を及ぼします。

### 絆レベル
プレイヤーがそのキャラクターの所有者となってからのブロック時間が経過するほど増える数値です。この数値に応じて、キャラクターのレベルは元の値の2倍まで増加します。

より長く所持しているキャラクターが強くなるようにすることで、所持している既出キャラクターが新規キャラクターの登場によって相対的に弱体化することを抑制しています。この数値はミント時や譲渡時といった所有者が変更されるタイミングで初期化されます。

$p_{own}$: 所有ブロック期間、$p_{\rm{speed}}$ : 絆レベル上昇速度を決める定数、$l$ : キャラクターの現在のレベルから、絆レベル $b$ は以下計算式で算出されます。

$$
b = \max\left(\frac{p_{\rm{own}}}{p_{\rm{speed}}}, 2l\right)
$$

絆レベルが多い分だけ、攻撃力が上がります。通常のレベルと絆レベルを組み合わせたダメージ計算は以下の通りで、絆レベル分の内訳は1ポイント当たり1/10となっています。

$$
{\rm{damage}} = 10 l + b 
$$

### データ構造

キャラクターに紐づくこれらの情報は変更が生じるたびにその履歴がブロックバンバーと共に保存されており、チェックポイントとして格納されています。この実装により、***バトル中など、ある時点でのキャラクター情報を継続的に参照する必要がある際に、キャラクターのtransferやレベルアップなどの書き換えが実施されたとしても、元の情報を参照し続けることが可能になります。***（チェックポイントについては Nouns DAO の proposal 時点での delegate を参照する実装に影響を受けています。）

### キャラクター画像

弊チームにイラストを書けるメンバーがいなかったため、 [Stable Diffusion](https://stability.ai/)によって作成しました。

<br> </br>

 
---
- [次を読む ](./32_coin.md)

- [HOMEに戻る](../../README.md) 
