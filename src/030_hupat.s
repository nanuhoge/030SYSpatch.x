**********************************************************
** Human ver3.0[12]の中のパッチ
**********************************************************
patch_human_code:
		movem.l	d1/a0/a2,-(sp)

		tst.b	(F_DEVCALL,pc)
		beq	patch_human_code_end3

		move.b	(human_version,pc),d0
		lea	(patch_devcall_301,pc),a0
		cmpi.b	#VER301,d0
		beq	patch_human_code3
		lea	(patch_devcall_302,pc),a0
		cmpi.b	#VER302,d0
		beq	patch_human_code3
		lea	(patch_devcall_215,pc),a0

patch_human_code3:
		move.w	(4,a0),([a0])

patch_human_code_end3:
		pea	human_patch_ok_message(pc)
		DOS	_PRINT
		addq.l	#4,sp
		moveq	#0,d0

		movem.l	(sp)+,d1/a0/a2
		rts

human_patch_ok_message:
		dc.b	'Humanにパッチを当てました',13,10,0

	.even


patch_devcall_301:
	dc.l	$0000DE0A			* patch address
	dc.w		$6020			* , new

patch_devcall_302:
	dc.l	$0000DEFA
	dc.w		$6046

patch_devcall_215:
	dc.l	$0000DEEC
	dc.w		$6020

