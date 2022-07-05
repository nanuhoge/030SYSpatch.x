********************************************************************
*
*	_30SYSpatch.x version 2.11 for MC68030 on X680x0
*
********************************************************************

	.include IOCSCALL.MAC
	.include DOSCALL.MAC

	.include SYSpatch.MAC

	.cpu	68030

MAGIC_NO1	equ	'X_30'
MAGIC_NO2	equ	'2.11'


VER215		equ	-1
VER301		equ	0
VER302		equ	1


SYS030		equ	0
SYS_30		equ	1

	.text

		dc.l	-1
		dc.w	$8000
		dc.l	device_strategy
		dc.l	device_interrupt
		dc.b	'_30SYSp*'

device_reqhead:
		ds.l	1

device_strategy:
		move.l	a5,device_reqhead
		rts

device_interrupt:
		movem.l	d1-d7/a0-a6,-(sp)
		movea.l	(device_reqhead,pc),a5
		tst.b	(2,a5)
		beq	device_initialize
device_error_exit:
		move.w	#$5003,d0
device_exit:
		move.b	d0,(3,a5)	; low
		ror.w	#8,d0
		move.b	d0,(4,a5)	; high
		ror.w	#8,d0
		movem.l	(sp)+,d1-d7/a0-a6
		rts

*---------------------------------------------------------
* IOCS-AC:キャッシュ制御ルーチンの追加機能
*---------------------------------------------------------
new_IOCS_AC:	.cpu	68000
		movem.l	d1/d2,-(sp)
		cmpi.w	#$F000,d1
		beq	new_IOCS_AC_F000
		cmpi.w	#$F002,d1
		beq	new_IOCS_AC_F002
		cmpi.w	#$F001,d1
		beq	new_IOCS_AC_F001
		cmpi.w	#$8000,d1
		beq	new_IOCS_AC_8000
		cmpi.w	#$8001,d1
		beq	new_IOCS_AC_8001
		cmpi.w	#$8004,d1
		beq	new_IOCS_AC_8004
		movem.l	(sp)+,d1/d2
		move.l	(orig_IOCS_AC,pc),-(sp)		; 対Xellent30(s)
		rts
		.cpu	68030
orig_IOCS_AC:	ds.l	1


	.include 030_iocs_ac.s


*---------------------------------------------------------
* 論理アドレス関連サブルーチン・内部呼び出し
*---------------------------------------------------------
set_memory_mode:
		movem.l	d1/d2,-(sp)
		bra	new_IOCS_AC_F002

** ここまでは常駐後に必須な処理 **
;-----------------------------------------------------------------------------
; MMUテーブルバッファ
;-----------------------------------------------------------------------------
mmu_table_buf:
	ds.b	128*4+128*4+2048*8+16
;		TIA   TIB   TIC    padding

** ここから後ろは常駐後に不要な処理 **
;-----------------------------------------------------------------------------
; デバイスドライバ初期化ルーチン常駐部
;-----------------------------------------------------------------------------
initial_0:
		bsr	SYSpatch_main
		tst.l	d0
		beq	initial_ok
		pea	ng_message(pc)
		DOS	_PRINT
		addq.l	#4,sp
		DOS	_INKEY
		bra	initial_error

initial_ok:
		move.l	(VMM_MAX,pc),d7
		beq	vmm_set_skip
		move.l	(Hu_MEMMAX),d1
		cmp.l	d1,d7
		bne	@f
		pea	(vmm_use2_msg,pc)
		bra	1f
@@:		move.l	d7,(Hu_MEMMAX)
		lea	(vmm_st_msg,pc),a0
		bsr	numout
		movea.l	d1,a1
		move.w	#(1<<10),d2
		move.l	#PAGE_SIZE,d1
@@:		cmpa.l	d7,a1
		bcc	@f
		bsr	set_memory_mode
		adda.l	d1,a1
		bra	@b
@@:		move.l	a1,d1
		lea	(vmm_ed_msg,pc),a0
		bsr	numout
		pea	(vmm_use1_msg,pc)
1:		DOS	_PRINT
		addq.l	#4,sp
vmm_set_skip:
		clr.w	d0
		bra	device_exit


ng_message:
		dc.b	'パッチ作業を中断します',13,10
		dc.b	'----- 何かキーを押してください -----',13,10
		dc.b	13,10,0

vmm_use1_msg:	dc.b	'仮想メインメモリ['
vmm_st_msg:	dc.b	'00000000～'
vmm_ed_msg:	dc.b	'00000000'
		dc.b	']が使えます',13,10,0
vmm_use2_msg:	dc.b	'仮想メインメモリが使えます',13,10,0

		.even

*------------------------------------------------------------
**		１６進文字列a0から値をd0に取り出す
*------------------------------------------------------------
*------------------------------------------------------------
**		d1の値を１６進文字列にしてa0に出す
*------------------------------------------------------------
*------------------------------------------------------------
*  MPUチェック(無意味
*------------------------------------------------------------

	.include 030_comm1.s


*------------------------------------------------------------
*  パッチルーチン
*------------------------------------------------------------
SYSpatch_main:
		bsr	pre_patch
		tst.l	d0
		bne	patch_error
patch_1:
		bsr	post_patch
		tst.l	d0
		bne	patch_error
patch_2:
		moveq	#0,d0
patch_error:
		bsr	CFLUSH
		rts

*------------------------------------------------------------
* パッチとかべつにしないけど・・・
*------------------------------------------------------------
pre_patch:
		movem.l	d1/d2/a0-a3,-(sp)
		move.w	sr,-(sp)
		ori.w	#$700,sr		* 割込禁止

		clr.l	-(sp)
		pmove.l	(sp),TC			* MMU disable
		addq.l	#4,sp

		bsr	CFLUSH

		bsr	mmu_table		** MMUテーブル作成 & MMUイネーブル

		lea	(new_IOCS_AC,pc),a1
		move.w	#$01AC,d1
		IOCS	_B_INTVCS
		move.l	d0,orig_IOCS_AC

		pea	(newIOCS_msg,pc)
		DOS	_PRINT
		addq.l	#4,sp

		moveq	#0,d0
pre_patch_end:
		move.w	(sp)+,sr
		movem.l	(sp)+,d1/d2/a0-a3
		rts

newIOCS_msg:	dc.b	'拡張IOCS-$AC が使えます',13,10,0
		.even

*------------------------------------------------------------
*  MMUテーブル作成
*------------------------------------------------------------
mmu_table:
		movem.l	d1-d3/a0-a2,-(sp)

		lea	(mmu_table_buf+16-1,pc),a2
		move.l	a2,d0
		andi.w	#.not.(16-1),d0
		movea.l	d0,a2

		bsr	MakeMMUtable

	********************
	** MMU enable     **
	********************

		lea	(root_reg,pc),a0
		move.l	a2,(4,a0)		* MMU table
		pmove.q	(a0),CRP		* CRP
		pmove.q	(a0),SRP		* SRP
		pmove.l	(8,a0),TC		* TC
		bsr	CFLUSH

;; WPは止め
;;		lea	(a2),a1
;;		moveq	#3-1,d3
;;@@:		moveq	#-1,d2
;;		bsr	set_memory_mode
;;		move.w	d0,d2
;;		bset.l	#2,d2			* WP bit
;;		bsr	set_memory_mode
;;		lea	(PAGE_SIZE,a1),a1
;;		dbra	d3,@b

		move.l	a2,d1
		lea	mmu_table_ok_message_data(pc),a0
		bsr	numout
		pea	mmu_table_ok_message(pc)
		DOS	_PRINT
		addq.l	#4,sp

		moveq	#0,d0
		movem.l	(sp)+,d1-d3/a0-a2
		rts

root_reg:	dc.l	$8000_0002
		dc.l	0						; root address
		dc.l	%1000_0010_1101_0000_0111_0111_0101_0000	; TC register
*			 E      SF page IS   TIA  TIB  TIC  TID

mmu_table_ok_message:
	dc.b	'MMU-table['
mmu_table_ok_message_data:
	dc.b	'00000000～]を作成しました',13,10,0
	.even

*------------------------------------------------------------
*  起動後のパッチ
*------------------------------------------------------------

	.include 030_postpat.s


*---------------------------------------------------------
* MMU table を作る
*---------------------------------------------------------
MakeMMUtable:
		movem.l	d0-d3/a0-a2,-(sp)

		move.l	a2,d3

	********************
	** make TIA table **
	********************

		lea	128*4+%1010(a2),a0  * TIAは128個その後にTIBが続く。%10 は DT=$2 のこと
		move.w	#128-1,d2
loop_set_TIA:
		move.l	a0,-(sp)
		move.l	a2,-(sp)
		bsr	mem_write	  * TIAは全て同じTIBテーブルを指す
		addq.l	#8,sp
		addq.l	#4,a2
		dbra	d2,loop_set_TIA	  * X68030が上位8bitをデコードしてないから

	********************
	** make TIB table **
	********************

		lea	128*4+%1011(a2),a0  * TIBは128個その後にTICが続く。%11 は DT=$3 のこと
		move.w	#128/2-1,d2
loop_set_TIB:
		move.l	a0,-(sp)
		move.l	a2,-(sp)	  * X68030が上位8bitをデコードしてないから
		bsr	mem_write
		addi.l	#64*4,(sp)	  * TIBの始めの64個と後の64個は同じTICを指す
		bsr	mem_write
		addq.l	#8,sp
		addq.l	#4,a2
		lea	32*8(a0),a0	  * TICは32個づつ
		dbra	d2,loop_set_TIB

		lea	128/2*4(a2),a2	  * TIBの後半64個分を進めてTICトップへ

	********************
	** make TIC table **
	********************

		lea	(TIC_table_define_mode,pc),a0
		lea	TIC_table_define(pc),a1	* アドレス範囲ごとに設定
		move.l	(a1)+,d1		* RAM top
		move.l	d3,d2			* MMU top
		or.l	(a1)+,d2
		move.l	d2,d3
		andi.w	#$E000,d2
loop_set_TIC:
		cmp.l	d2,d1
		blt	next_TIC
		move.l	d3,d1
		move.l	(a1)+,d2
		move.l	d2,d3
		beq	end_make_MMU_table
		addq.l	#4,a0
		andi.w	#$E000,d2
next_TIC:
		move.l	(a0),-(sp)
		move.l	a2,-(sp)
		bsr	mem_write
		move.l	d1,(sp)
		pea	(4,a2)
		bsr	mem_write
		lea	(12,sp),sp
		addq.l	#8,a2
next_PAGE:
		addi.l	#PAGE_SIZE,d1
		bra	loop_set_TIC

end_make_MMU_table:
		move.l	a2,d0
;;省メモリ化	addi.l	#PAGE_SIZE-1,d0
;;		andi.w	#$e000,d0
		move.l	d0,(14,a5)

		pflusha
		movem.l	(sp)+,d0-d3/a0-a2
		rts

TIC_table_define:
		****	address
		dc.l	$00000000	* MEM
		dc.l	$00000000	* MMU table & Patched ROM
		dc.l	$00C00000	* I/O(Cache-Inhibit)
		dc.l	$00EC0000	* User I/O
		dc.l	$00ED0000	* SRAM & others
		dc.l	$00F00000	* ROM
		dc.l	$01000000	* dummy
		dc.l	0

TIC_table_define_mode:
		****	      G S C MUWDt
		dc.l	%1110010000000001	*MEM
		dc.l	%1110010000000001	*MMU
		dc.l	%1110010101000001	*I/O
		dc.l	%1110010001000001	*User I/O
		dc.l	%1110010101000001	*SRAM & others
		dc.l	%1110010100000001	*ROM


**********************************************************
** Human ver3.0[12]の中のパッチ
**********************************************************

	.include 030_hupat.s


**********************************************************
** パッチ個別設定
**********************************************************
patch_etc_magic:
	movem.l	d1/d2/a0-a2,-(sp)

	** MPUフラグを３にセット(無意味な…)
	move.b	#3,MPUTYPE

	** Human.sys SUPERVISOR Protectをパッチ設定
	lea	$6800,a0
	move.l	#$13C000E8,d0
	move.l	#$60014E75,d1
	moveq	#$10,d2
	swap	d2
HuSUPER_set_code_search:
	addq.l	#2,a0			* Human.sys パッチあて箇所の探査
	cmpa.l	d2,a0			* １Ｍバイト越えたら異常終了する
	bcc	HuSUPER_code_error
	cmp.l	(a0),d0
	bne	HuSUPER_set_code_search
	cmp.l	4(a0),d1
	bne	HuSUPER_set_code_search
	move.w	#OP_JMP,(a0)+		* jmp op code
	lea	(HuSUPER,pc),a2
	move.l	a2,d1
	move.l	d1,(a0)			* jump address
	pea	HuSUPER_copy_msg(pc)
	DOS	_PRINT
	addq.l	#4,sp

	move.b	(human_version,pc),d0
	lea	(p1_data,pc),a1
	move.l	(a1)+,a0
	cmpi.b	#VER215,d0
	beq	@f
	move.l	(a1)+,a0
	cmpi.b	#VER301,d0
	beq	@f
	move.l	(a1)+,a0
@@:
	cmpi.l	#$43E8_0100,(a0)	; lea ($100,a0),a1
	bne	skip_clearBSS_set
	move.w	#OP_JMP,(a0)+
	move.l	#clearBSS,(a0)
skip_clearBSS_set:
	moveq	#0,d0

patch_etc_magic_exit
	movem.l	(sp)+,d1/d2/a0-a2
	rts

p1_data:
	.dc.l	$9936		; 2.15
	.dc.l	$9802		; 3.01
	.dc.l	$98a0		; 3.02


HuSUPER_code_error
	pea	HuSUPER_error_msg(pc)
	DOS	_PRINT
	addq.l	#4,sp
	moveq	#-1,d0
	bra	patch_etc_magic_exit

HuSUPER_copy_msg:
	dc.b	'HuSUPERを設定しました'
	dc.b	13,10,0
HuSUPER_error_msg:
	dc.b	'HuSUPERを設定できませんでした',13,10,0


F_DEVCALL:	dc.b	0	* '+'
	.even
VMM_MAX:	dc.l	0

;-----------------------------------------------------------------------------
; デバイスドライバ初期化ルーチン
;-----------------------------------------------------------------------------
device_initialize:
		pea	(device_name,pc)
		DOS	_PRINT
		addq.l	#4,sp

		move.l	#ROM_TOP,SYStop		; むだ２

		move.l	18(a5),a0
skipname:	tst.b	(a0)+
		bne	skipname
getparam:	move.b	(a0)+,d1
		bne	@f
		move.b	(a0)+,d1
		beq	no_param

@@:		cmpi.b	#'@',d1
		bne	@f
		SRAM_WE
		bset.b	#4,SCSIFLAG		* MPU転送
		SRAM_WP
		bra	getparam

@@:		cmpi.b	#'A',d1
		bne	@f
		SRAM_WE
		bset.b	#7,SCSIFLAG		* 転送バイト数設定
		SRAM_WP
		bra	getparam

@@:		cmpi.b	#'B',d1
		bne	@f
		SRAM_WE
		st	POOON			* ぽ～ん設定
		SRAM_WP
		bra	getparam

@@:		cmpi.b	#'e',d1
		bne	@f
		move.l	d0,-(sp)
		bsr	numin
		cmpi.l	#$00C00000,d0
		bhi	opt_e_exit
		move.w	d0,d1
		andi.w	#$1fff,d1
		bne	opt_e_exit
		move.l	d0,(VMM_MAX)
opt_e_exit:	move.l	(sp)+,d0
		bra	getparam

@@:		cmpi.b	#'+',d1
		bne	@f
		st	F_DEVCALL
@@:		bra	getparam

no_param:
		bsr	MPUcheck	** MPUを判定する
		tst.l	d0
		beq	initial_0

		pea	skip_message(pc)
		DOS	_PRINT
		addq.l	#4,sp
initial_error:
		bra	device_error_exit

*------------------------------------------------------------
*  MPUチェック(無意味
*------------------------------------------------------------
MPUcheck:
		move.l	$0010,-(sp)		* 不当命令のエントリを退避
		move.l	#MPUcheck_trap,$0010	* 不当命令をトラップ
		nop
		movec	CAAR,d0			* 68000/68040 で不当命令
		movec	CACR,d0
		bset.l	#13,d0			* WA bit
		movec	d0,CACR
		movec	CACR,d0
		btst.l	#13,d0			* 68020 では zero になるはず
		beq	MPU_is_020
		clr.l	d0
MPUcheck_1:
		move.l	(sp)+,$0010
		rts

MPUcheck_trap:
		moveq	#-1,d0
		move.l	#MPUcheck_1,(2,sp)
		rte

MPU_is_020:	moveq	#-1,d0
		bra	MPUcheck_1

;---------------------------------------------------------------------
; コマンドライン実行部
;---------------------------------------------------------------------
command_entry:
		move.w	#$1a,-(sp)
		DOS	_INPOUT

		IOCS	_ROMVER
		cmpi.l	#$13921127,d0		* v1.3 92/11/27
		bne	@f

		pea	$00ff0e76		* ROM絶対アドレス
		DOS	_SUPER_JSR
		addq.l	#4,sp

@@:		pea	(device_name,pc)
		DOS	_PRINT
		addq.l	#6,sp

		DOS	_EXIT

		dc.b	'!'
device_name:	dc.b	13,10
		dc.b	'_30SYSpatch.x v'
		dc.l	MAGIC_NO2
		dc.b	' for MC68030 on X680x0 by bisco',13,10
		dc.b	'         special thanks BEEPs , PUNA',13,10,0
skip_message:
		dc.b	'MC68030ではありません。パッチをスキップします。',13,10
		dc.b	13,10,0

	.end	command_entry
