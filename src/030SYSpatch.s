********************************************************************
*
*	030SYSpatch.x version 2.11 for MC68030 on X68030
*
*	IPL/IOCS-ROM になぜかパッチをする(謎)
*
********************************************************************

	.include IOCSCALL.MAC
	.include DOSCALL.MAC

	.include SYSpatch.MAC

	.cpu	68030

MAGIC_NO1	equ	'X030'
MAGIC_NO2	equ	'2.11'

MAGIC_040	equ	'040T'

VER215		equ	-1
VER301		equ	0
VER302		equ	1

SYS030		equ	1
SYS_30		equ	0

	.text

		dc.l	-1
		dc.w	$8000
		dc.l	device_strategy
		dc.l	device_interrupt
		dc.b	'030SYSp*'

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
		move.b	d0,(3,a5)
		ror.w	#8,d0
		move.b	d0,(4,a5)
		ror.w	#8,d0
		movem.l	(sp)+,d1-d7/a0-a6
		rts

device_initialize:
		pea	(device_name,pc)
		DOS	_PRINT
		addq.l	#4,sp

		cmpi.l	#MAGIC_040,(ROM_TOP)
		beq	SYSpatched

		move.l	Hu_MEMMAX,d0
		move.l	d0,RAM_END
		subi.l	#$10000,d0
		movea.l	d0,a1
		tst.w	d0
		bne	invalid_param

		move.l	d0,SYStop
		subi.l	#PAGE_SIZE*2,d0
		movea.l	d0,a2
		move.l	d0,Hu_MEMMAX

		move.l	18(a5),a0
skipname:	tst.b	(a0)+
		bne	skipname
getparam:	move.b	(a0)+,d1
		bne	@f
		move.b	(a0)+,d1
		beq	no_param

@@:		cmpi.b	#'*',d1
		bne	@f
		st	F_RAM_END
		bra	getparam

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

@@:		cmpi.b	#'C',d1
		bne	@f
		st	F_SCSISWC
		bra	getparam

@@:		cmpi.b	#'!',d1
		bne	@f
		subi.l	#ROMDB_LEN,d0	* ROMDB領域先頭
		st	F_ROMDB
		move.l	d0,dbtop
		bra	getparam

@@:		cmpi.b	#'0',d1
		bne	@f
		st	F_SWAP_MEM
		bra	getparam

@@:		cmpi.b	#'1',d1
		bne	@f
		st	F_WP_PATCH
		bra	getparam

@@:		cmpi.b	#'$',d1
		bne	@f
		st	F_DBON
		bra	getparam

@@:		cmpi.b	#'+',d1
		bne	@f
		st	F_DEVCALL
		bra	getparam

@@:		cmpi.b	#'x',d1
		bne	@f
		move.l	d0,-(sp)
		bsr	numin
		move.l	d0,X68030_pal_data
		move.l	(sp)+,d0
		bra	getparam

@@:		cmpi.b	#'M',d1
		bne	@f
		move.b	#1,F_EXPMAP
		bra	getparam

@@:		cmpi.b	#'N',d1
		bne	@f
		move.b	#2,F_EXPMAP
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

@@:		bra	getparam


no_param:	move.l	d0,Hu_MEMMAX	* ここでメモリ確保

		bsr	MPUcheck	** MPUを判定する
		tst.l	d0
		beq	initial_0

		pea	skip_message(pc)
		DOS	_PRINT
		addq.l	#4,sp
MPU_is_EC03:
		clr.w	d0
		move.b	(F_EXPMAP,pc),d0
		mulu.w	#PAGE_SIZE,d0
		add.l	d0,Hu_MEMMAX
		move.b	F_RAM_END(pc),d0
		beq	initial_error
		move.l	RAM_END(pc),Hu_MEMMAX	* 確保したメモリを返却
						* 汚いプログラムだなあ
		bra	initial_error

initial_0:
		bsr	SYSpatch_main		** システムにパッチを当てる(引数:a1)
		tst.l	d0
		beq	initial_ok

		tst.b	(F_MPU_is_EC030,pc)
		bne	MPU_is_EC03

		pea	ng_message(pc)
		DOS	_PRINT
		addq.l	#4,sp
		DOS	_INKEY
		bra	initial_error

initial_ok:
		move.l	(VMM_MAX,pc),d7
		beq	vmm_set_skip
		move.l	(Hu_MEMMAX),d1
		move.l	d7,(Hu_MEMMAX)
		lea	(vmm_st_msg,pc),a0
		bsr	numout
		movea.l	d1,a1
		move.w	#(1<<10),d2
@@:		bsr	set_memory_mode
		lea	(PAGE_SIZE,a1),a1
		cmpa.l	d7,a1
		bcs	@b
		move.l	a1,d1
		lea	(vmm_ed_msg,pc),a0
		bsr	numout
		pea	(vmm_use1_msg,pc)
		DOS	_PRINT
		addq.l	#4,sp
vmm_set_skip:
		tst.b	(F_ROMDB,pc)
		beq	skip_setup_romdb
		tst.b	(F_DBON,pc)
		beq	skip_exp_map
		movem.l	d0-d7/a0-a6,-(sp)
		movea.l	ROMDB_INST,a0
		lea	$1000,a6
		jsr	(a0)
		movem.l	(sp)+,d0-d7/a0-a6
		pea	setup_romdb(pc)
		DOS	_PRINT
		addq.l	#4,sp
		bra	skip_exp_map

skip_setup_romdb:
		tst.b	(F_EXPMAP,pc)
		beq	skip_exp_map
		bsr	expand_mapping
skip_exp_map:
		pea	ok_message(pc)
		DOS	_PRINT
		addq.l	#4,sp
initial_end:
		move.l	#device_initialize,(14,a5)
device_normal_exit:
		clr.l	d0
		bra	device_exit

initial_error:
		bra	device_error_exit

SYSpatched:
		pea	patched_msg(pc)
		DOS	_PRINT
		addq.l	#4,sp
		bra	initial_error

invalid_param:	pea	usage(pc)
		DOS	_PRINT
		addq.l	#4,sp
		bra	initial_error

		dc.b	'!'
device_name:	dc.b	13,10
		dc.b	'030SYSpatch.x v'
		dc.l	MAGIC_NO2
		dc.b	' for MC68030 on X68030 by bisco',13,10
		dc.b	'         special thanks BEEPs , PUNA',13,10,0

usage:		dc.b	13,10
		dc.b	'パッチ用RAMのエリアが64Kバイト境界からはずれています。',13,10
		dc.b	'config.sysの先頭で登録してください。',13,10
		dc.b	13,10,0

skip_message:
		dc.b	'MC68030ではありません。パッチをスキップします。',13,10
		dc.b	13,10,0
patched_msg:	dc.b	27,'[35m[[ 040TURBO ]]',27,'[m',13,10,0
ok_message:
		dc.b	'パッチ作業を完了しました',13,10
		dc.b	13,10,0
ng_message:
		dc.b	'パッチ作業を中断します',13,10
		dc.b	'----- 何かキーを押してください -----',13,10
		dc.b	13,10,0
setup_romdb:
		dc.b	'ROMDBを起動しました',13,10,0

vmm_use1_msg:	dc.b	'仮想メインメモリ['
vmm_st_msg:	dc.b	'00000000～'
vmm_ed_msg:	dc.b	'00000000'
		dc.b	']が使えます',13,10,0


F_RAM_END:	dc.b	0	* '*'
F_DBON:		dc.b	0	* '$'
F_DEVCALL:	dc.b	0	* '+'
F_SCSISWC:	dc.b	0	* 'C'
F_MPU_is_EC030:	dc.b	0
		.even
VMM_MAX:	dc.l	0	* 'e'


*------------------------------------------------------------
**		１６進文字列a0から値をd0に取り出す
*------------------------------------------------------------
*------------------------------------------------------------
**		d1の値を１６進文字列にしてa0に出す
*------------------------------------------------------------

	.include 030_comm1.s

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
*  起動前のIPL/IOCS-ROMのパッチ
*	A1:パッチ用RAMの先頭番地
*	A2:MMUテーブル開始番地
*------------------------------------------------------------
pre_patch:
		movem.l	d1/d2/a0-a3,-(sp)
		move.w	sr,-(sp)
		ori.w	#$700,sr		* 割込禁止

		IOCS	_ROMVER
		cmpi.l	#$13921127,d0		* v1.3 92/11/27
		bne	romver_error

		move.l	a1,d0
		andi.l	#$000FFFFF,d0
		cmpi.l	#$000F0000,d0
		bne	align_error

		lea	ROM_TOP,a3

		cmpi.l	#MAGIC_NO1,(a3)		** パッチ済確認用キー１
		bne	pre_patch_1st
		cmpi.l	#MAGIC_NO2,4(a3)	** パッチ済確認用キー２
		bne	pre_patch_1st

		exg	a1,a3
		move.l	#$10000-4,d1
		tst.b	(F_ROMDB,pc)
		beq	@f
		move.l	#(PMEM_MAX-ROMDB_TOP)-4,d1
		lea	ROMDB_TOP,a1
@@:		bsr	crc_calc
		exg	a1,a3
		cmp.l	(a3,d1.l),d0
		beq	pre_patch_ok

	******************************
	** パッチ当て最初のステージ **
	******************************
pre_patch_1st:
		clr.l	-(sp)
		pmove.l	(sp),TC			* MMU disable
		addq.l	#4,sp

		move.w	#$10000/4-1,d1
		lea	ROM_TOP,a0		** IPL/IOCS-ROMをRAM上に展開
		move.l	a1,a3
loop_pre_patch2:
		move.l	(a0)+,d0
		move.l	d0,(a3)
		cmp.l	(a3)+,d0
		bne	memory_error
		dbra	d1,loop_pre_patch2

		tst.b	(F_ROMDB,pc)
		beq	skip_romdb_install

		move.w	#ROMDB_LEN/4-1,d1
		lea	ROMDB_TOP,a0		* ROMDBをRAM上に展開
		movea.l	(dbtop,pc),a3
loop_pre_patch2_romdb:
		move.l	(a0)+,d0
		move.l	d0,(a3)
		cmp.l	(a3)+,d0
		bne	memory_error
		dbra	d1,loop_pre_patch2_romdb

skip_romdb_install:

		bsr	mmu_table		** MMUテーブル作成 & MMUイネーブル

	******************************************************************
	**								**
	**  この時点でＲＯＭ領域はパッチＲＯＭ領域(RAM)になっている	**
	**  パッチＲＯＭ領域(RAM)の物理アドレスは (SYSpat) に格納	**
	**								**
	******************************************************************

		lea	ROM_TOP,a1

		bsr	check_mmu_active
		tst.l	d0
		bne	mmu_inactive_error

		bsr	patch_rom_new_code	** ROMへの追加コード書き込み
		tst.l	d0
		bne	pre_patch_error

		bsr	patch_rom_code		** 変更したいコードをパッチ
		tst.l	d0
		bne	pre_patch_error

		bsr	patch_romdb		** ROMDBのパッチとマッピング
		tst.l	d0
		bne	pre_patch_error

		bsr	patch_wotaku		** 特殊設定
		tst.l	d0
		bne	pre_patch_error

		bsr	patch_rom_magic		** 個別設定
		tst.l	d0
		bne	pre_patch_error

		bsr	patchWP
		bra	pre_patch_ok

pre_patch_restart:
		pea	restart_message(pc)
		DOS	_PRINT
		addq.l	#4,sp

		clr.l	d0
		move.l	d0,d1
		jmp	$00FF0038		** パッチＲＯＭでリスタート

pre_patch_ok:
		lea	ROM_TOP,a1
		move.w	($0400+$8F*4),d1
		cmp.w	SYStop(pc),d1		** IOCS$8F(ROMVER)のエントリがROMを指してるか？
		beq	pre_patch_restart
		move.l	a1,d0
		swap	d0
		cmp.w	d0,d1			** パッチROM論理アドレスを指してるか？
		bne	patch_restart_error

		move.w	#$f000,d1
		bsr	new_IOCS_AC_ffc75a
		move.l	d0,d1
		lea	pre_patch_ok_message_data(pc),a0
		bsr	numout
		move.b	(pre_patch_ok_message_data+2,pc),pre_patch_ok_message_data+10+2
		move.b	(pre_patch_ok_message_data+3,pc),pre_patch_ok_message_data+10+3
		pea	pre_patch_ok_message(pc)
		DOS	_PRINT
		addq.l	#4,sp

		tst.b	(F_ROMDB,pc)
		beq	skip_romdb_inst_ok
		pea	romdb_use_ok_msg(pc)
		DOS	_PRINT
		addq.l	#4,sp
skip_romdb_inst_ok

		moveq	#0,d0
pre_patch_end:
		move.w	(sp)+,sr
		movem.l	(sp)+,d1/d2/a0-a3
		rts

patch_restart_error:
		pea	ng_restart_message(pc)
		bra	pre_patch_error_exit

pre_patch_error:
		pea	ng_pre_patch_message(pc)
		bra	pre_patch_error_exit

romver_error:
		pea	ng_romver_message(pc)
		bra	pre_patch_error_exit

memory_error:
		move.l	a2,d1
		subq.l	#4,d1
		lea	ng_memory_message_data(pc),a0
		bsr	numout
		pea	ng_memory_message(pc)
		bra	pre_patch_error_exit

mmu_inactive_error:
		clr.l	-(sp)
		pmove.l	(sp),TC
		addq.l	#4,sp
		st	F_MPU_is_EC030
		pea	mmu_inactive_message(pc)
		bra	pre_patch_error_exit

align_error:
		pea	ng_align_message(pc)
pre_patch_error_exit:
		DOS	_PRINT
		addq.l	#4,sp
		moveq	#-1,d0
		bra	pre_patch_end

romdb_use_ok_msg:
		dc.b	'ROMDBが使えます',13,10,0
pre_patch_ok_message:
		dc.b	'IPL/IOCSをRAM['
pre_patch_ok_message_data:
		dc.b	'00000000～0000FFFF]上にコピーしてパッチしました',13,10,0
restart_message:
		dc.b	'パッチしたIPL/IOCS-RAM上でリスタートします。',13,10,0
ng_pre_patch_message:
		dc.b	'IPL/IOCS-RAMのパッチができませんでした。',13,10,0
ng_romver_message:
		dc.b	'IPL/IOCS-ROMのバージョンが違います。',13,10,0
ng_memory_message:
		dc.b	'パッチ用RAM('
ng_memory_message_data:
		dc.b	'00000000)のアクセスでエラーが発生しました。',13,10,0
ng_align_message:
		dc.b	'パッチ用RAMのアドレスが不適当です。',13,10,0
ng_restart_message:
		dc.b	'リスタート処理に異常があります。',13,10,0
mmu_inactive_message:
		dc.b	'MC68EC030です。パッチを中断します。',13,10,0
	.even

;-----------------------------------------------------------------------------
; MMUが動作しているかみる 68030/68EC030 の判別(動作未確認)
;-----------------------------------------------------------------------------
check_mmu_active:
		moveq	#-1,d0
		move.l	a0,-(sp)
		move.l	$0008,-(sp)		* バスエラーのエントリを退避
		movea.l	sp,a0
		move.l	#BUSERR_trap,$0008	* バスエラーをトラップ
		nop
		move.l	(a1),d0
		move.l	#MAGIC_NO1,(a1)		* バスエラーチェック
		move.l	d0,(a1)
		clr.l	d0
BUSERR_trap:	movea.l	a0,sp
		move.l	(sp)+,$0008
		movea.l	(sp)+,a0
		rts

*------------------------------------------------------------
*  MMUテーブル作成／IOCS ROM領域にパッチRAMをマッピング
*	A2:MMUテーブル用RAMの先頭番地
*	I/Oエリアがキャシュオフになるようなテーブルを作る
*------------------------------------------------------------
mmu_table:
		movem.l	d1-d3/a0-a2,-(sp)

		bsr	MakeMMUtable

	********************
	** MMU enable     **
	********************

		move.l	a2,d3
		
		movea.l	(SYStop,pc),a2
		lea	(MTBL_OFS,a2),a2
		lea	(root_reg,pc),a0
		move.l	a2,(4,a0)		* MMU table
		pmove.q	(a0),CRP		* CRP
		pmove.q	(a0),SRP		* SRP
		pmove.l	(8,a0),TC		* TC
		bsr	CFLUSH

		movea.l	d3,a2
		
		lea	(a2),a1
		moveq	#2-1,d3			; long format にすると 1-page 多くなる
@@:		moveq	#-1,d2
		bsr	set_memory_mode
		move.w	d0,d2
		bset.l	#2,d2			* WP bit
		bsr	set_memory_mode
		lea	(PAGE_SIZE,a1),a1
		dbra	d3,@b

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


*********************************************************
** IPL/IOCS-ROMに追加するコード
**	A1:パッチ用RAMの先頭番地
*********************************************************
patch_rom_new_code:
		movem.l	d1/d2/a0-a3,-(sp)

		lea	table_rom_new_code(pc),a0
		move.w	#(table_rom_new_code_end-table_rom_new_code-4)/2-1,d2
		move.l	(a0)+,d0		** 代替ルーチンの書き込みアドレス算出
		move.l	a1,d1
		move.w	d0,d1
		move.l	d1,a2

loop_rom_new_code:
		move.w	(a0)+,(a2)+		** パッチ
		dbra	d2,loop_rom_new_code
		move.l	d1,a2			** a2:new_codeの先頭

** パッチプログラム内の絶対アドレスをリロケート
patch_rom_new_code_relocate:
		move.l	(a0)+,d2		** リロケートテーブル
		beq	patch_rom_new_code_jmp

		move.l	(a2,d2.l),d0		** 代替ルーチンの該当アドレス
		move.l	a1,d1
		move.w	d0,d1
		move.l	d1,(a2,d2.l)
		bra	patch_rom_new_code_relocate

** パッチプログラム内の絶対アドレスをリロケート
patch_rom_new_code_jmp:
		move.l	(a0)+,d0		** jmpテーブル
		beq	patch_rom_new_code_end

		move.l	a1,d1
		move.w	d0,d1
		move.l	d1,a3			** パッチすべきアドレス

		move.l	(a0)+,d0
		add.l	a2,d0			** 代替ルーチンのエントリアドレス

		move.w	#OP_JMP,(a3)+		** jmp のコード
		move.l	d0,(a3)
		bra	patch_rom_new_code_jmp

patch_rom_new_code_end:
		moveq	#0,d0
		movem.l	(sp)+,d1/d2/a0-a3
		rts

*---------------------------------------------------------
table_rom_new_code:
		dc.l	$00FFF000	** この番地はフリー
					** 以下のプログラムが転送される
*---------------------------------------------------------

*---------------------------------------------------------
* IOCS-AC:キャッシュ制御ルーチンの追加機能
*---------------------------------------------------------
new_IOCS_AC_ffc75a:
		movem.l	d1/d2,-(sp)
		moveq	#-1,d0
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
org_IOCS_AC_entry
		jmp	$FFC760


	.include 030_iocs_ac.s


*---------------------------------------------------------
* ブート時の処理
*---------------------------------------------------------
new_BOOT_ff0038:
		move.w	#$2700,sr
		lea	$2000,sp
		reset
		moveq	#0,d0
		movec	d0,CACR				; cache off
		move.w	#%00_1000_0000_1000,d0
		movec	d0,CACR				; cache flush
		pflusha

		movea.l	(SYStop,pc),a2
		suba.l	#PAGE_SIZE*2,a2
		bsr	MakeMMUtable

		lea	(a2),a1
		moveq	#2-1,d3			; long format にすると 1-page 多くなる
@@:		moveq	#-1,d2
		bsr	set_memory_mode
		move.w	d0,d2
		bset.l	#2,d2			* WP bit
		bsr	set_memory_mode
		lea	(PAGE_SIZE,a1),a1
		dbra	d3,@b

		bsr	patchWP

		tst.l	ROMDB_INST
		bne	org_BOOT_entry

		cmpi.b	#2,(F_EXPMAP,pc)
		bne	org_BOOT_entry

		lea	LABWORK,a1
		move.l	#PABWORK,d2
		bsr	set_area_mapping
		moveq	#-1,d2
		bsr	set_memory_mode
		move.l	d0,d2
		bclr.l	#2,d2
		bsr	set_memory_mode
org_BOOT_entry:
		jmp	$FF0042

F_EXPMAP:	dc.b	0	* 'M' 'N'
	.even

*---------------------------------------------------------
* ブート時の謎な表示
*---------------------------------------------------------
X68030_logo_disp:
		moveq	#1,d1
		move.l	(X68030_pal_data,pc),d2
		IOCS	_TPALET
		move.w	#7,d1
		moveq	#_B_COLOR,d0
		rts

X68030_pal_data:	* X68030の色  デフォルトは赤っぽい色
	dc.l	$07C0


*---------------------------------------------------------
* MMU table を作る
*---------------------------------------------------------
MakeMMUtable:
		movem.l	d0-d3/a0-a2,-(sp)

		move.l	a2,d3

	********************
	** make TIA table **
	********************

		movea.l	(SYStop,pc),a2
		lea	(MTBL_OFS,a2),a2
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

;;;		lea	128*4+%1011(a2),a0  * TIBは128個その後にTICが続く。%11 は DT=$3 のこと
		movea.l	d3,a0
		lea	(%1011,a0),a0
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

;;;		lea	128/2*4(a2),a2	  * TIBの後半64個分を進めてTICトップへ
		movea.l	d3,a2

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
		tst.b	(F_SWAP_MEM,pc)
		beq	no_SYSpat_area
		move.l	d1,d0
		swap	d0
		cmp.w	(SYStop,pc),d0		* パッチ領域？
		bne	no_SYSpat_area
		move.w	#$00FF,d0		* 論理ＲＯＭアドレス
		bra	set_swap_TIC

no_SYSpat_area:
		move.l	d1,d0
		swap	d0
		cmpi.w	#$00FF,d0		* ＲＯＭ領域？
		bne	no_p_ROM_area
		move.w	(SYStop,pc),d0		* 論理パッチアドレス
set_swap_TIC:
		move.l	(a0),-(sp)
		move.l	a2,-(sp)
		bsr	mem_write
		swap	d0
		move.l	d0,(sp)
		pea	(4,a2)
		bsr	mem_write
		lea	(12,sp),sp
		addq.l	#8,a2
		bra	next_PAGE

no_p_ROM_area:
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
		dc.l	%1110010100000001	*patch
		dc.l	%1110010101000001	*I/O
		dc.l	%1110010001000001	*User I/O
		dc.l	%1110010101000001	*SRAM & others
		dc.l	%1110010100000001	*ROM


F_SWAP_MEM:	dc.b	0	* '0'
	.even

*---------------------------------------------------------
* パッチROM領域をライトプロテクト
*---------------------------------------------------------
patchWP:	movem.l	d0-d3/a1,-(sp)
		moveq	#$10000/PAGE_SIZE-1,d1
		lea	ROM_TOP,a1
		move.l	(SYStop,pc),d3
		bsr	loop_patchWP

		tst.b	(F_ROMDB,pc)
		beq	@f
		moveq	#ROMDB_LEN/PAGE_SIZE-1,d1
		lea	ROMDB_TOP,a1
		move.l	(dbtop,pc),d3
		bsr	loop_patchWP

@@:		movem.l	(sp)+,d0-d3/a1
		rts

loop_patchWP:	moveq	#-1,d2
		bsr	set_memory_mode
		move.w	d0,d2
		ori.b	#%1000_0100,d2
		bsr	set_memory_mode
		lea	(PAGE_SIZE,a1),a1
		tst.b	(F_WP_PATCH,pc)
		bne	@f
		exg	d3,a1
		moveq	#-1,d2
		bsr	set_memory_mode
		move.w	d0,d2
		ori.b	#%1000_0100,d2
		bsr	set_memory_mode
		lea	(PAGE_SIZE,a1),a1
		exg	a1,d3
@@:		dbra	d1,loop_patchWP
		rts

F_ROMDB:	dc.b	0	* '!'
F_WP_PATCH:	dc.b	0	* '1'
dbtop:		dc.l	0
		.even

*---------------------------------------------------------
* 論理アドレス関連サブルーチン・内部呼び出し
*---------------------------------------------------------
set_area_mapping:
		movem.l	d1/d2,-(sp)
		bra	new_IOCS_AC_F001

set_memory_mode:
		movem.l	d1/d2,-(sp)
		bra	new_IOCS_AC_F002


table_rom_new_code_end:

**以下リロケーション情報
		dc.l	org_IOCS_AC_entry+2-(table_rom_new_code+4)
		dc.l	org_BOOT_entry+2-(table_rom_new_code+4)
		dc.l	0
**以下本来のコード部にパッチして追加コードへのジャンプ
		dc.l	$FFC75A
		dc.l	new_IOCS_AC_ffc75a-(table_rom_new_code+4)
		dc.l	$FF0038
		dc.l	new_BOOT_ff0038-(table_rom_new_code+4)
		dc.l	0

*********************************************************
* ROMDBのマッピング
*********************************************************
patch_romdb:
		movem.l	d1-d3/a1,-(sp)

		tst.b	(F_ROMDB,pc)
		beq	patch_romdb_nasi

		move.l	#PAGE_SIZE,d3
		moveq	#ROMDB_LEN/PAGE_SIZE-1,d1
		lea	ROMDB_TOP,a1		* マッピング先論理アドレス
		move.l	(dbtop,pc),d2		* マッピング元物理アドレス
loop_dbmap:
		bsr	set_area_mapping
		adda.l	d3,a1
		add.l	d3,d2
		dbra	d1,loop_dbmap
		bra	patch_romdb_ok_end

patch_romdb_nasi:
		clr.l	ROMDB_INST
patch_romdb_ok_end:
		moveq	#0,d0
		movem.l	(sp)+,d1-d3/a1
		rts

*********************************************************
** IPL/IOCS-ROM内のプログラムのパッチ
*********************************************************
patch_rom_code:
		movem.l	d1/a0/a2,-(sp)

		lea	table_rom_code(pc),a0
		move.l	#ROM_TOP,d0
loop_rom_code:
		move.w	(a0)+,d0	** パッチ当てる元アドレス
		beq	patch_rom_code_end
		move.l	d0,a2		** アドレス
		move.w	(a0)+,(a2)	** パッチ
		bra	loop_rom_code

patch_rom_code_end:
		moveq	#0,d0

		movem.l	(sp)+,d1/a0/a2
		rts

	.even

table_rom_code:
	dc.w	$0D96
	dc.w		$604E		* movea.l a7,a0	 -> bra.s $00FF0DE6
		** ソフトウェアリセットで MMU disable にならないよーにする

	dc.w	$0042
	dc.w		$F000
	dc.w	$0044
	dc.w		$2400
	dc.w	$0046
	dc.w		$203C
	dc.w	$0048
	dc.w		$0000
	dc.w	$004A
	dc.w		$0808
	dc.w	$004C
	dc.w		$4E7B
	dc.w	$004E
	dc.w		$0002
	dc.w	$0050
	dc.w		$7A00
		** なんとなく気分的変更
		**  00FF0042	moveq	#$00,d5		 -> pflusha
		**  00FF0044	cmp.l	$00FF1AF6(pc),d0 -> move.l  #$0808,d0
		**  00FF0048	bne.s	$00FF0052	 -> movec   d0,CACR
		**  00FF004A	cmp.l	$00FF1AFA(pc),d1 -> 
		**  00FF004E	bne.s	$00FF0052	 -> 
		**  00FF0050	moveq	#$FF,d5		 -> moveq   #0,d5

	dc.w	0

*---------------------------------------------------------
* ヲタクなパッチ
*---------------------------------------------------------
patch_wotaku:
		movem.l	d1/a0/a2,-(sp)

		tst.b	(F_SCSISWC,pc)
		beq	@f
		move.l	$FFCD0E+$B*4,$FFCD0E+$4*4
		move.l	$FFCD0E+$C*4,$FFCD0E+$5*4
@@:

		lea	$FF0EA0,a0
		move.w	#OP_JSR,(a0)+
		move.l	(table_rom_new_code,pc),d1
		addi.l	#X68030_logo_disp-(table_rom_new_code+4),d1
		move.l	d1,(a0)			* jump address

		lea	(wotaku_rom_code,pc),a0
@@:		move.l	(a0)+,d0
		beq	patch_wotaku_end
		move.l	d0,a2
		move.w	(a0)+,(a2)
		bra	@b

patch_wotaku_end:
		movea.l	(SCSI_addr1,pc),a2
		move.w	(HSCSI_code1,pc),(a2)
		movea.l	(SCSI_addr2,pc),a2
		moveq	#32-1,d0
		move.w	(HSCSI_code2,pc),d1
@@:		move.w	d1,(a2)+
		dbra	d0,@b

		lea	(X68030_logo_data,pc),a0
		lea	$FF12AC,a2
		moveq	#224/4-1,d0
@@:		move.l	(a0)+,(a2)+
		dbra	d0,@b

		moveq	#0,d0
patch_wotaku_exit:
		movem.l	(sp)+,d1/a0/a2
		rts


wotaku_rom_code:
	dc.l	$FF1260			* 'Memory Managiment Unit(MMU)'のスペルミス
	dc.w		'em'			       ~
	dc.l	$FF02B6			* ブート画面を少し長時間表示
	dc.w		$2048
	dc.l	$FF02B8
	dc.w		$2048
	dc.l	$FF1202
	dc.w		'in'
	dc.l	$FF1204
	dc.w		'g '
	dc.l	$FF1206
	dc.w		'Un'
	dc.l	$FF1208
	dc.w		'it'
	dc.l	0	** end1 **	謎なパッチはこの前に追加していく

SCSI_addr1:	dc.l	$FFD320
HSCSI_code1:	lsr.l  #5,d2

SCSI_addr2:	dc.l	$FFD330
HSCSI_code2:	move.b (a4),(a1)+

X68030_logo_data:
	dc.b	$03,$ff,$f9,$ff,$e0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$80
	dc.b	$0c,$c0,$c0,$ff,$83,$fe,$1f,$f8,$3f,$e0,$ff,$80,$01,$80,$0c,$c1
	dc.b	$83,$ff,$cf,$ff,$3f,$fc,$ff,$f3,$ff,$c0,$00,$c0,$06,$63,$07,$01
	dc.b	$dc,$07,$70,$1d,$c0,$77,$01,$c0,$00,$c0,$06,$66,$06,$01,$d8,$03
	dc.b	$60,$0d,$80,$36,$00,$c0,$00,$60,$03,$3c,$06,$00,$1c,$06,$60,$0d
	dc.b	$80,$36,$00,$c0,$00,$60,$03,$38,$0f,$ff,$1f,$fe,$c0,$18,$00,$6c
	dc.b	$01,$80,$00,$30,$01,$90,$0f,$ff,$9f,$fc,$c0,$18,$1f,$ec,$01,$80
	dc.b	$01,$30,$01,$80,$0c,$03,$b8,$1e,$c0,$18,$1f,$cc,$01,$80,$03,$98
	dc.b	$00,$c0,$18,$01,$b0,$0e,$c0,$18,$00,$e8,$01,$80,$07,$98,$00,$c0
	dc.b	$18,$03,$60,$0d,$80,$36,$00,$d8,$03,$00,$0c,$cc,$00,$60,$18,$03
	dc.b	$60,$0d,$80,$36,$00,$d8,$03,$00,$18,$cc,$00,$60,$1c,$07,$70,$1d
	dc.b	$c0,$77,$01,$dc,$07,$00,$30,$66,$00,$30,$1f,$fe,$7f,$f9,$ff,$e7
	dc.b	$ff,$9f,$fe,$00,$60,$66,$00,$30,$0f,$f8,$3f,$e0,$ff,$c3,$fe,$0f
	dc.b	$f8,$00,$ff,$f3,$ff,$f8,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00


**********************************************************
** IPL/IOCS-ROMパッチ個別設定
**********************************************************
patch_rom_magic:
		movem.l	d1/a1,-(sp)

		lea	ROM_TOP,a1

		** パッチ確認用キー埋め込み
		move.l	#MAGIC_NO1,(a1)
		move.l	#MAGIC_NO2,(4,a1)

		move.l	#$10000-4,d1
		tst.b	(F_ROMDB,pc)
		beq	@f
		move.l	#(PMEM_MAX-ROMDB_TOP)-4,d1
		lea	ROMDB_TOP,a1
@@:		bsr	crc_calc
		move.l	d0,(a1,d1.l)
		** 非破壊確認用 CRC 埋め込み

		clr.l	d0
		movem.l	(sp)+,d1/a1
		rts

**********************************************************
** Human ver3.0[12]の中のパッチ
**********************************************************

	.include 030_hupat.s


**********************************************************
** パッチ個別設定
**********************************************************
patch_etc_magic:
	movem.l	d1/d2/a0-a2,-(sp)

	** 追加コードの先頭アドレス
	movea.l	table_rom_new_code(pc),a2

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
	move.l	a2,d1
	addi.l	#HuSUPER-(table_rom_new_code+4),d1
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
	move.l	a2,d1
	addi.l	#clearBSS-(table_rom_new_code+4),d1
	move.w	#OP_JMP,(a0)+
	move.l	d1,(a0)
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
	.even

*------------------------------------------------------------
* CRC を計算する
* in	A1 : アドレス
*	D1 : 長さ
* out	D0 : 計算結果
*------------------------------------------------------------
crc_calc:	movem.l	d1-d4/a0/a1,-(sp)
		lea	(CRC_WORK,pc),a0
		move.w	#256-1,d2
		move.l	#$EDB88320,d3
1:		move.l	d2,d4
		moveq	#8-1,d0
2:		lsr.l	#1,d4
		bcc	@f
		eor.l	d3,d4
@@:		dbra	d0,2b
		move.l	d4,(a0,d2.w*4)
		dbra	d2,1b

		moveq	#-1,d0
		clr.w	d4
@@:		move.b	(a1)+,d4
		eor.b	d0,d4
		move.l	(a0,d4.w*4),d3
		lsr.l	#8,d0
		eor.l	d3,d0
		subq.l	#1,d1
		bne	@b
		not.l	d0
		movem.l	(sp)+,d1-d4/a0/a1
		rts

*------------------------------------------------------------
* メモリ増設???
*------------------------------------------------------------
expand_mapping:
	movea.l	Hu_MEMMAX,a3
	lea	$4000,a2
	move.l	#PAGE_SIZE,d5
	clr.w	d6
	move.b	(F_EXPMAP,pc),d6

	move.l	a2,d1
	cmpi.w	#1,d6
	beq	@f
	sub.l	d5,d1
@@:	lea	(pa1,pc),a0
	bsr	numout
	move.w	d6,d7
	mulu.w	d5,d7
	add.l	d7,d1
	subq.l	#1,d1
	lea	(pa2,pc),a0
	bsr	numout

	move.l	a3,d1
	lea	(la1,pc),a0
	bsr	numout
	move.w	d6,d7
	mulu.w	d5,d7
	add.l	d7,d1
	subq.l	#1,d1
	lea	(la2,pc),a0
	bsr	numout

	move.w	d6,d7
	subq.w	#1,d7
re_map_loop:
		movea.l	a3,a1
		move.l	a2,d2

		bsr	set_area_mapping	; 未使用メモリの再配置
		move.l	d2,-(sp)		; 物理アドレスをプッシュ
		moveq	#-1,d2
		bsr	set_memory_mode		; ページ設定の取得
		bclr.l	#2,d0			; 'W' をリセット
		move.w	d0,d2
		bsr	set_memory_mode		; ページ情報の設定
		move.l	(sp)+,a1		; 論理アドレスとしてポップ
		moveq	#-1,d2
		bsr	set_memory_mode		; ページ設定の取得
		bset.l	#2,d0			; 念のため 'W' をセット
		move.w	d0,d2
		bsr	set_memory_mode		; ページ情報の設定

		adda.l	d5,a3
		suba.l	d5,a2
	dbra	d7,re_map_loop

	move.w	d6,d7
	mulu.w	d5,d7
	add.l	d7,Hu_MEMMAX
	pea	(expm1,pc)
	DOS	_PRINT
	addq.l	#4,sp
	rts

expm1:		dc.b	'物理アドレス['
pa1:		dc.b	'00000000～'
pa2:		dc.b	'00000000]を',13,10
		dc.b	'論理アドレス['
la1:		dc.b	'00000000～'
la2:		dc.b	'00000000]にマッピングしました',13,10,0

	.even

***********************************************************************************************
command_exec:
		move.w	#$1a,-(sp)
		DOS	_INPOUT
		addq.l	#2,sp

		moveq	#1,d1
		moveq	#-1,d2
		IOCS	_TPALET
		move.l	d0,-(sp)

		move.l	a2,-(sp)

		pea	$ff0e76		* ROM絶対アドレス
		DOS	_SUPER_JSR
		pea	(device_name,pc)
		DOS	_PRINT
		addq.l	#8,sp

		movea.l	(sp)+,a2
		tst.b	(a2)+
		bne	skip_c1
		pea	(pressmes,pc)
		DOS	_PRINT
		addq.l	#4,sp
		DOS	_INKEY
skip_c1:	moveq	#1,d1
		move.l	(sp)+,d2
		IOCS	_TPALET

		DOS	_EXIT

pressmes:	dc.b	13,10,'press key.',13,10,0


	.bss

RAM_END:	ds.l	1
CRC_WORK:	ds.l	256

	.end	command_exec
