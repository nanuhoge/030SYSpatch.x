;--------------------------------------------------------------------------------------
;
;	030SYSpatch.x
;	_30SYSpatch.x
;
;		IOCS $AC, HuSUPER 共通部分
;
;--------------------------------------------------------------------------------------


SYStop:		.dc.l	0	* パッチＲＯＭ領域(RAM)の物理アドレス

new_IOCS_AC_8000:	* 030SYSpatchバージョンを D0 に返す
			* パッチＲＯＭ領域(RAM)の物理アドレス A1 に返す
			* バージョンには MAGIC_NO2 を返す

		movea.l	SYStop(pc),a1
		move.l	#MAGIC_NO2,d0
		movem.l	(sp)+,d1/d2
		rts


new_IOCS_AC_8001:	* MMUキャッシュモードの取得
			* A1で示されるページ(8K単位)のキャッシュモードをD0に返す
			* D0=%0?:キャッシャブル・ライトスルー
			* D0=%1?:キャッシュ禁止
			* D0にはキャッシュモードが返る

		move.l	a0,-(sp)
		ptestw	#1,(a1),#3,a0			; get TIC address
		move.l	a0,-(sp)
		bsr	mem_read
		move.l	(sp)+,d0
		bfextu	d0{25:2},d0
		movea.l	(sp)+,a0
		movem.l	(sp)+,d1/d2
		rts


new_IOCS_AC_8004:	* キャッシュ状態設定
			* A1で示されるページ(8K単位)のキャッシュモードをD2に設定
			* D0=%0?:キャッシャブル・ライトスルー
			* D0=%1?:キャッシュ禁止
			* D0には以前のキャッシュモードが返る

		move.l	a0,-(sp)
		ptestw	#1,(a1),#3,a0			; get TIC address
		asl.l	#5,d2				; cache mode
		move.l	#%1000000,d0
		and.l	d0,d2
		not.l	d0
		move.l	a0,-(sp)
		bsr	mem_read
		move.l	(sp)+,d1
		and.l	d1,d0
		or.l	d0,d2
		move.l	a0,-(sp)
		bsr	mem_read
		move.l	(sp)+,d0
		move.l	d2,-(sp)
		move.l	a0,-(sp)
		bsr	mem_write
		addq.l	#8,sp
		bfextu	d0{25:2},d0
		pflush	#0,#0,(a1)
		bsr	CFLUSH
		movea.l	(sp)+,a0
		movem.l	(sp)+,d1/d2
		rts


new_IOCS_AC_F000:	* 論理アドレス→物理アドレス変換
			* A1 : 論理アドレス(変換前)
			* D0 に物理アドレス(変換後)が返る

		move.l	a0,-(sp)
		ptestw	#1,(a1),#2,a0			; get TIB address
		move.l	a0,-(sp)
		bsr	mem_read
		move.l	(sp)+,d1
		ptestw	#1,(a1),#3,a0			; get TIC address
		andi.b	#%11,d1
		subq.b	#2,d1
		beq	@f
		addq.l	#4,a0
@@:		move.l	a0,-(sp)
		bsr	mem_read
		move.l	(sp)+,d0
		move.w	a1,d1
		bfins	d1,d0{19:13}
		movea.l	(sp)+,a0
		movem.l	(sp)+,d1/d2
		rts

S_3to4	.macro	reg
	.local	user,exit
	btst.l	#8,reg			; S bit for 68030
	beq	user
	bclr.l	#8,reg
	bset.l	#7,reg			; S bit 68040 compatible
	bra	exit
user:	bclr.l	#7,reg
exit:
	.endm

S_4to3	.macro	reg
	.local	user,exit
	btst.l	#7,reg			; S bit 68040 compatible
	beq	user
	bclr.l	#7,reg
	bset.l	#8,reg			; S bit for 68030
	bra	exit
user:	bclr.l	#8,reg
exit:
	.endm

new_IOCS_AC_F001:	* 物理アドレスを論理アドレスにマッピング
			* D2 : マッピングしたい物理アドレス
			* A1 : マッピング先の論理アドレス
			* D0 にページディスクリプタが返る

		move.l	a0,-(sp)
		ptestw	#1,(a1),#2,a0			; get TIB address
		move.l	a0,-(sp)
		bsr	mem_read
		move.l	(sp)+,d1
		ptestw	#1,(a1),#3,a0			; get TIC address
		move.l	a0,-(sp)
		bsr	mem_read
		move.l	(sp)+,d0
		bfins	d0,d2{19:13}
		andi.b	#%11,d1
		subq.b	#2,d1
		beq	@f
		addq.l	#4,a0
@@:		move.l	d2,-(sp)
		move.l	a0,-(sp)		; push page address pointer
		bsr	mem_write
		addq.l	#8,sp
		S_3to4	d0
		pflush	#0,#0,(a1)
		bsr	CFLUSH
		movea.l	(sp)+,a0
		movem.l	(sp)+,d1/d2
		rts


new_IOCS_AC_F002:	* 指定論理アドレスのモードを設定したり見てみたり
			* D2 : モード  -1 の場合には現在値を D0 返す
			* A1 : 論理アドレス

		move.l	a0,-(sp)
		ptestw	#1,(a1),#3,a0			; get TIC address
		move.l	a0,-(sp)
		bsr	mem_read
		move.l	(sp)+,d0
		move.l	d0,d1
		S_3to4	d0
		cmpi.w	#-1,d2
		beq	new_IOCS_AC_F002_exit
		S_4to3	d2
		bfins	d2,d1{19:13}
		move.l	d1,-(sp)
		move.l	a0,-(sp)
		bsr	mem_write
		addq.l	#8,sp
		pflush	#0,#0,(a1)
		bsr	CFLUSH
new_IOCS_AC_F002_exit:
		movea.l	(sp)+,a0
		movem.l	(sp)+,d1/d2
		rts


;-----------------------------------------------------------------------------
; 物理メモリの操作  mem_read(addr) / mem_write(addr1, data)
;   addr は物理アドレス
;   data は書き込むデータ
;   読み出しデータは addr の位置に格納される
;-----------------------------------------------------------------------------
		.offset	4+4*2
mad:		ds.l	1		; 物理アドレス(リードデータ)
mdt:		ds.l	1		; ライトデータ
		.text
mem_read:	movem.l		d7/a0,-(sp)
		bsr		Pma_SET
		move.l		(a0),(mad,sp)
		bra		m_rw_exit

mem_write:	movem.l		d7/a0,-(sp)
		bsr		Pma_SET
		move.l		(mdt,sp),(a0)

m_rw_exit:	move.l		d7,-(sp)
		pmovefd.l	(sp),TT0
		addq.l		#4,sp
		movem.l		(sp)+,d7/a0
		rts

Pma_SET:
		move.l		(mad+4,sp),d7
		ori.l		#$ff000000,d7
		movea.l		d7,a0
		subq.l		#4,sp
		pmove.l		TT0,(sp)
		move.l		(sp),d7
		move.l		(ttreg,pc),(sp)
		pmovefd.l	(sp),TT0
		addq.l		#4,sp
		rts

ttreg:		dc.l		$FF000000|%10000101_0000_0111	; $FFxxxxxx は透過変換領域

;-----------------------------------------------------------------------------
; キャッシュのフラッシュ   「d1 を破壊するので注意すること」
;-----------------------------------------------------------------------------
CFLUSH:
		movec	CACR,d1
		ori.w	#%00_1000_0000_1000,d1
		movec	d1,CACR				; cache flush
		rts

*--------------------------------------------------------------------
* Human.sys SUPERVISOR Protect 全デバイスドライバ登録後に実行される
*--------------------------------------------------------------------
HuSUPER:
	.if SYS_30				; _30SYSpatch.x だけで行う
		move.b	d0,$00e86001		* X680x0 ハードウェア・スーパーバイザ設定
	.endif

		movem.l	d0-d4/a1,-(sp)
		move.l	#PAGE_SIZE,d4
		move.l	$1C24,d3		* Human68kでの値は腐ってるので自前で計算する。
		add.l	d4,d3
		subq.l	#1,d3
		bfextu	d3{0:32-13},d3
		subq.w	#1,d3			* dbra対策
		suba.l	a1,a1
HuSUPER_area_set:
		moveq	#-1,d2
		bsr	set_memory_mode
		move.w	d0,d2
		bset.l	#7,d2			* set Supervisor bit  68040 compatible
		bsr	set_memory_mode
		adda.l	d4,a1
		dbra	d3,HuSUPER_area_set

		pea	install_msg(pc)
		DOS	_PRINT
		addq.l	#4,sp
		movem.l	(sp)+,d0-d4/a1
		rts

install_msg:	dc.b	13,10
		dc.b	'Human.sys 領域をスーパーバイザ保護します',13,10,0
	.even


*---------------------------------------------------------
* Human68k 余計な小細工
*---------------------------------------------------------
clearBSS:	.cpu	68000		; 対Xellent30(s) / 68000 命令以外を使わんよーにする
		lea	($100,a0),a1
		adda.l	d3,a1
		move.l	d6,d0
		beq	9f
		lsr.l	#8,d0
		beq	1f
		movem.l	d1-d5/a2-a4,-(sp)
		moveq	#0,d1
		move.l	d1,d2
		move.l	d1,d3
		move.l	d1,d4
		move.l	d1,d5
		movea.l	d1,a2
		movea.l	d1,a3
		movea.l	d1,a4
		subq.w	#1,d0
@@:		movem.l	d1-d5/a2-a4,(a1)
		movem.l	d1-d5/a2-a4,(32,a1)
		movem.l	d1-d5/a2-a4,(64,a1)
		movem.l	d1-d5/a2-a4,(96,a1)
		movem.l	d1-d5/a2-a4,(128,a1)
		movem.l	d1-d5/a2-a4,(160,a1)
		movem.l	d1-d5/a2-a4,(192,a1)
		movem.l	d1-d5/a2-a4,(224,a1)
		lea	(256,a1),a1
		dbra	d0,@b
		movem.l	(sp)+,d1-d5/a2-a4
1:		move.l	d6,d0
		andi.w	#$00ff,d0
		beq	9f
		subq.w	#1,d0
@@:		clr.b	(a1)+
		dbra	d0,@b
9:		rts
		.cpu	68030

