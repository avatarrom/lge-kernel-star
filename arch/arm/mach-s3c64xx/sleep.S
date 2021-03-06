/* linux/arch/arm/plat-s3c64xx/sleep.S
 *
 * Copyright 2008 Openmoko, Inc.
 * Copyright 2008 Simtec Electronics
 *	Ben Dooks <ben@simtec.co.uk>
 *	http://armlinux.simtec.co.uk/
 *
 * S3C64XX CPU sleep code
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
*/

#include <linux/linkage.h>
#include <asm/assembler.h>
#include <mach/map.h>

#undef S3C64XX_VA_GPIO
#define S3C64XX_VA_GPIO (0x0)

#include <mach/regs-gpio.h>
#include <mach/gpio-bank-n.h>

#define LL_UART (S3C_PA_UART + (0x400 * CONFIG_S3C_LOWLEVEL_UART_PORT))

	.text

	/* s3c_cpu_save
	 *
	 * Save enough processor state to allow the restart of the pm.c
	 * code after resume.
	 *
	 * entry:
	 *	r1 = v:p offset
	*/

ENTRY(s3c_cpu_save)
	stmfd	sp!, { r4 - r12, lr }
	ldr	r3, =resume_with_mmu
	bl	cpu_suspend

	@@ call final suspend code
	ldr	r0, =pm_cpu_sleep
	ldr	pc, [r0]
	
	@@ return to the caller, after the MMU is turned on.
	@@ restore the last bits of the stack and return.
resume_with_mmu:
	ldmfd	sp!, { r4 - r12, pc }	@ return, from sp from s3c_cpu_save

	/* Sleep magic, the word before the resume entry point so that the
	 * bootloader can check for a resumeable image. */

	.word	0x2bedf00d

	/* s3c_cpu_reusme
	 *
	 * This is the entry point, stored by whatever method the bootloader
	 * requires to get the kernel runnign again. This code expects to be
	 * entered with no caches live and the MMU disabled. It will then
	 * restore the MMU and other basic CP registers saved and restart
	 * the kernel C code to finish the resume code.
	*/

ENTRY(s3c_cpu_resume)
	msr	cpsr_c, #PSR_I_BIT | PSR_F_BIT | SVC_MODE
	ldr	r2, =LL_UART		/* for debug */

#ifdef CONFIG_S3C_PM_DEBUG_LED_SMDK
	/* Initialise the GPIO state if we are debugging via the SMDK LEDs,
	 * as the uboot version supplied resets these to inputs during the
	 * resume checks.
	*/

	ldr	r3, =S3C64XX_PA_GPIO
	ldr	r0, [ r3, #S3C64XX_GPNCON ]
	bic	r0, r0, #(S3C64XX_GPN_CONMASK(12) | S3C64XX_GPN_CONMASK(13) | \
			  S3C64XX_GPN_CONMASK(14) | S3C64XX_GPN_CONMASK(15))
	orr	r0, r0, #(S3C64XX_GPN_OUTPUT(12) | S3C64XX_GPN_OUTPUT(13) | \
			  S3C64XX_GPN_OUTPUT(14) | S3C64XX_GPN_OUTPUT(15))
	str	r0, [ r3, #S3C64XX_GPNCON ]

	ldr	r0, [ r3, #S3C64XX_GPNDAT ]
	bic	r0, r0, #0xf << 12			@ GPN12..15
	orr	r0, r0, #1 << 15			@ GPN15
	str	r0, [ r3, #S3C64XX_GPNDAT ]
#endif
	b	cpu_resume
