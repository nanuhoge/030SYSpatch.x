*------------------------------------------------------------
*  起動後のパッチ
*------------------------------------------------------------
post_patch:
		move.l	d1,-(sp)

		DOS	_VERNUM
		moveq	#VER301,d1
		cmpi.w	#$0301,d0
		beq	dos_ver_ok
		moveq	#VER302,d1
		cmpi.w	#$0302,d0
		beq	dos_ver_ok
		moveq	#VER215,d1
		cmpi.w	#$020f,d0
		bne	humanver_error

dos_ver_ok:
		move.b	d1,human_version
		bsr	patch_human_code	** Humanの変更したいコードをパッチ
		tst.l	d0
		bne	post_patch_end

		bsr	patch_etc_magic		** 個別設定
		tst.l	d0
		bne	post_patch_end

		moveq	#0,d0
post_patch_end:
		move.l	(sp)+,d1
		rts

humanver_error:
		pea	ng_humanver_message(pc)
		DOS	_PRINT
		addq.l	#4,sp
		moveq	#-1,d0
		bra	post_patch_end

ng_humanver_message:
		dc.b	'Human68kのバージョンが違います。',13,10,0
human_version:
		dc.b	VER301
	.even

