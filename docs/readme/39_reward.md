バトルシステム

<[前のページに戻る](./38_randomslot.md)>

 < [HOMEに戻る](../../README.md)  >
___
### バトル終了時の報酬の配布

バトル時には勝者に対してのみ報酬のPLMCoinが支払われ、敗者は無報酬・無支払い、引き分けの場合は両者報酬が支払われます。

勝者の報酬は、両プレイヤーそれぞれの合計レベルより計算され、レベル差が小さい・レベルが自分より大きいプレイヤーを倒した時により大きな報酬が得られるようになっています。

以下式が勝者の報酬になります。PLMCoinは育成に使用されるため、ポケットモンスターシリーズの経験値計算を参考に設計しました。

$$
\frac{51\times \rm{loserTotalLevel} \times (\rm{winnerTotalLevel}\times 2+ 102)^3}{(\rm{winnerTotalLevel} + \rm{loserTotalLevel}+ 102)^3} 
$$

Player AとPlayer Bの間で引き分けの場合、

Aの報酬が以下式で、Bの報酬も同様です。

$$
\frac{51\times \rm{TotalLevel}_A \times (\rm{TotalLevel}_A\times 2+ 102)^3}{(\rm{TotalLevel_A} + \rm{TotalLevel_B}+ 102)^3} 
$$

これにより、引き分けで配布される報酬の総量 < 勝ち負けがついた時に配布される報酬の総量 が成立しており、

勝利することに対しての相対的なインセンティブを高めています。

<br></br>

---

- [HOMEに戻る](../../README.md)
