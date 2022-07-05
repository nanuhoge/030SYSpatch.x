*------------------------------------------------------------
**		‚P‚Ui•¶š—ña0‚©‚ç’l‚ğd0‚Éæ‚èo‚·
*------------------------------------------------------------
numin:
		move.l	d1,-(sp)
		moveq	#0,d0
numinloop:	move.b	(a0)+,d1
		cmpi.b	#'0',d1
		blt	numend
		cmpi.b	#'9',d1
		ble	numin1
		cmpi.b	#'A',d1
		blt	numend
		cmpi.b	#'F',d1
		ble	numin2
		cmpi.b	#'a',d1
		blt	numend
		cmpi.b	#'f',d1
		ble	numin3
		bra	numend
numin1:
		subi.b	#'0',d1
		bra	numinx
numin2:
		subi.b	#'A'-10,d1
		bra	numinx
numin3:
		subi.b	#'a'-10,d1
		bra	numinx
numinx:
		asl.l	#4,d0
		or.b	d1,d0
		bra	numinloop
numend:
		move.l	(sp)+,d1
		rts

*------------------------------------------------------------
**		d1‚Ì’l‚ğ‚P‚Ui•¶š—ñ‚É‚µ‚Äa0‚Éo‚·
*------------------------------------------------------------
numout:
		movem.l	d0-d2/a0,-(sp)
		moveq	#8-1,d2
numoutloop:	
		rol.l	#4,d1
		move.b	d1,d0
		andi.w	#$F,d0
		move.b	hex(pc,d0.w),(a0)+
		dbra	d2,numoutloop
		movem.l	(sp)+,d0-d2/a0
		rts
hex:		dc.b	'0123456789ABCDEF'

