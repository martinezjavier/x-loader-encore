/*
 * Board specific setup info
 *
 * (C) Copyright 2004-2006
 * Texas Instruments, <www.ti.com>
 * Richard Woodruff <r-woodruff2@ti.com>
 *
 * See file CREDITS for list of people who contributed to this
 * project.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston,
 * MA 02111-1307 USA
 */

#include <config.h>
#include <asm/arch/cpu.h>
#include <asm/arch/mem.h>
#include <asm/arch/clocks.h>

_TEXT_BASE:
	.word	TEXT_BASE	/* sdram load addr from config.mk */

#if !defined(CFG_NAND_BOOT) && !defined(CFG_NAND_BOOT)
/**************************************************************************
 * cpy_clk_code: relocates clock code into SRAM where its safer to execute
 * R1 = SRAM destination address.
 *************************************************************************/
.global cpy_clk_code
 cpy_clk_code:
        /* Copy DPLL code into SRAM */ 
        adr     r0, go_to_speed         /* get addr of clock setting code */
        mov     r2, #384                /* r2 size to copy (div by 32 bytes) */
        mov     r1, r1                  /* r1 <- dest address (passed in) */
        add     r2, r2, r0              /* r2 <- source end address */
next2:
        ldmia   r0!, {r3-r10}           /* copy from source address [r0]    */
        stmia   r1!, {r3-r10}           /* copy to   target address [r1]    */
        cmp     r0, r2                  /* until source end address [r2]    */
        bne     next2
	mov	pc, lr                  /* back to caller */

/* **************************************************************************** 
 * NOTE: 3430 X-loader currently does not use this code.  
*   It could be removed its is kept for compatabily with u-boot.
 *
 *  go_to_speed: -Moves to bypass, -Commits clock dividers, -puts dpll at speed
 *               -executed from SRAM.
 *  R0 = CM_CLKEN_PLL-bypass value
 *  R1 = CM_CLKSEL1_PLL-m, n, and divider values
 *  R2 = CM_CLKSEL_CORE-divider values
 *  R3 = CM_IDLEST_CKGEN - addr dpll lock wait
 *
 *  Note: If core unlocks/relocks and SDRAM is running fast already it gets
 *        confused.  A reset of the controller gets it back.  Taking away its
 *        L3 when its not in self refresh seems bad for it.  Normally, this code
 *        runs from flash before SDR is init so that should be ok.
 ******************************************************************************/    
.global go_to_speed
 go_to_speed:
        stmfd sp!, {r4-r6}

        /* move into fast relock bypass */
        ldr     r4, pll_ctl_add
        str     r0, [r4]
wait1:
        ldr     r5, [r3]       /* get status */
        and     r5, r5, #0x1   /* isolate core status */
        cmp     r5, #0x1       /* still locked? */
        beq     wait1          /* if lock, loop */

	/* set new dpll dividers _after_ in bypass */
	ldr     r5, pll_div_add1
        str     r1, [r5]          /* set m, n, m2 */
        ldr     r5, pll_div_add2
        str     r2, [r5]          /* set l3/l4/.. dividers*/
        ldr     r5, pll_div_add3  /* wkup */
        ldr     r2, pll_div_val3  /* rsm val */
        str     r2, [r5]          
        ldr     r5, pll_div_add4  /* gfx */
        ldr     r2, pll_div_val4 
        str     r2, [r5]         
        ldr     r5, pll_div_add5  /* emu */
        ldr     r2, pll_div_val5 
        str     r2, [r5]     

        /* now prepare GPMC (flash) for new dpll speed */
	/* flash needs to be stable when we jump back to it */
        ldr     r5, flash_cfg3_addr
        ldr     r2, flash_cfg3_val
        str     r2, [r5]
        ldr     r5, flash_cfg4_addr
        ldr     r2, flash_cfg4_val
        str     r2, [r5]
        ldr     r5, flash_cfg5_addr
        ldr     r2, flash_cfg5_val
        str     r2, [r5]
        ldr     r5, flash_cfg1_addr
        ldr     r2, [r5]
        orr     r2, r2, #0x3     /* up gpmc divider */
        str     r2, [r5]

        /* lock DPLL3 and wait a bit */
        orr     r0, r0, #0x7   /* set up for lock mode */     
        str     r0, [r4]       /* lock */
        nop                    /* ARM slow at this point working at sys_clk */
        nop
        nop
        nop
wait2:
        ldr     r5, [r3]       /* get status */
        and     r5, r5, #0x1   /* isolate core status */
        cmp     r5, #0x1       /* still locked? */
        bne     wait2          /* if lock, loop */
        nop
        nop
        nop
        nop
        ldmfd sp!, {r4-r6}
        mov     pc, lr           /* back to caller, locked */        

_go_to_speed: .word go_to_speed

/* these constants need to be close for PIC code */
/* The Nor has to be in the Flash Base CS0 for this condition to happen */
flash_cfg1_addr:
    .word (GPMC_CONFIG_CS0 + GPMC_CONFIG1)
flash_cfg3_addr:
    .word  (GPMC_CONFIG_CS0 + GPMC_CONFIG3)
flash_cfg3_val: 
    .word  STNOR_GPMC_CONFIG3
flash_cfg4_addr:
    .word (GPMC_CONFIG_CS0 + GPMC_CONFIG4)
flash_cfg4_val:
    .word  STNOR_GPMC_CONFIG4
flash_cfg5_val:
    .word  STNOR_GPMC_CONFIG5
flash_cfg5_addr:
    .word (GPMC_CONFIG_CS0 + GPMC_CONFIG5)
pll_ctl_add:
    .word CM_CLKEN_PLL
pll_div_add1:
    .word CM_CLKSEL1_PLL 
pll_div_add2:
    .word CM_CLKSEL_CORE
pll_div_add3:
    .word CM_CLKSEL_WKUP
pll_div_val3:
    .word (WKUP_RSM << 1) 
pll_div_add4:
    .word CM_CLKSEL_GFX
pll_div_val4:
    .word (GFX_DIV << 0) 
pll_div_add5:
    .word CM_CLKSEL1_EMU
pll_div_val5:
    .word CLSEL1_EMU_VAL

#endif

.globl lowlevel_init
lowlevel_init:
	ldr	sp,	SRAM_STACK
        str     ip,	[sp]    /* stash old link register */
	mov	ip,	lr	/* save link reg across call */
	bl      s_init          /* go setup pll,mux,memory */
        ldr     ip,	[sp]    /* restore save ip */
	mov	lr,	ip	/* restore link reg */

	/* back to arch calling code */
	mov	pc,	lr

	/* the literal pools origin */
	.ltorg

REG_CONTROL_STATUS:
	.word CONTROL_STATUS
SRAM_STACK:
	.word LOW_LEVEL_SRAM_STACK

.globl get_mpu_dpll_param
get_mpu_dpll_param:
	adr r0, mpu_dpll_param
	mov pc, lr

.globl get_iva_dpll_param
get_iva_dpll_param:
	adr r0, iva_dpll_param
	mov pc, lr

.globl get_core_dpll_param
get_core_dpll_param:
	adr r0, core_dpll_param
	mov pc, lr

#if defined (CONFIG_ENCORE_1GHZ_SWITCH)
.globl get_core_dpll_param_3622
get_core_dpll_param_3622:
	adr r0, core_dpll_param_3622
	mov pc, lr
#endif

.globl get_per_dpll_param
get_per_dpll_param:
	adr r0, per_dpll_param
	mov pc, lr

/* DPLL(1-4) PARAM TABLES */
/* Each of the tables has M, N, FREQSEL, M2 values defined for nominal
 * OPP (1.2V). The fields are defined according to dpll_param struct(clock.c).
 * The values are defined for all possible sysclk and for ES1 and ES2.
 */

/* WARNING : Only the 26MHz timing has been tested */

/* Vdd1 = 1.20 for mpu and iva default */

mpu_dpll_param:
/* 12MHz */
.word 50, 0, 0, 1
.word  0, 0, 0, 0
/* 13MHz */
.word 600, 12, 0, 1
.word   0,  0, 0, 0
/* 19.2MHz */
.word 125, 3, 0, 1
.word   0, 0, 0, 0
/* 26MHz */
.word 300, 12, 0, 1
.word 300, 12, 0, 4 /* ARM@150MHz Low-power conf. used when battery is DEAD */
/* 38.4MHz */
.word 125, 7, 0, 1
.word   0, 0, 0, 0

iva_dpll_param:
/* 12MHz */
.word 130, 2, 0, 1
.word   0, 0, 0, 0
/* 13MHz */
.word 40, 0, 0, 1
.word  0, 0, 0, 0
/* 19.2MHz */
.word 325, 11, 0, 1
.word   0,  0, 0, 0
/* 26MHz */
.word 20, 0, 0, 1
.word 20, 0, 0, 2 /* Low power config used when battery is DEAD */
/* 38.4MHz */
.word 325, 23, 0, 1
.word   0,  0, 0, 0

#if defined(PRCM_CLK_CFG2_400MHZ)

core_dpll_param:
/* 12MHz */
.word 100, 2, 0, 1
.word   0, 0, 0, 0
/* 13MHz */
.word 400, 12, 0, 1
.word   0,  0, 0, 0
/* 19.2MHz */
.word 375, 17, 0, 1
.word   0,  0, 0, 0
/* 26MHz */
.word 200, 12, 0, 1
.word   0,  0, 0, 0
/* 38.4MHz */
.word 375, 35, 0, 1
.word   0,  0, 0, 0

/* for 3621 running @ 165Mhz as OMAP34xx processors */
#elif (defined(PRCM_CLK_CFG2_332MHZ) || defined (CONFIG_ENCORE_1GHZ_SWITCH))

core_dpll_param:
/* 12MHz */
.word M_12,N_12,FSEL_12,M2_12
.word    0,   0,     0, 0
/* 13MHz */
.word M_13,N_13,FSEL_13,M2_13
.word    0,   0,      0,   0
/* 19.2MHz */
.word M_19p2,N_19p2,FSEL_19p2,M2_19p2
.word      0,     0,        0,      0
/* 26MHz */
.word M_26,N_26,FSEL_26,M2_26
.word    0,   0,      0,    0
/* 38.4MHz */
.word M_38p4,N_38p4,FSEL_38p4,M2_38p4
.word      0,      0,       0,      0
#else
#error "Undefined memory speed"
#endif /* PRCM_CLK_CFG2_* */

#if defined (CONFIG_ENCORE_1GHZ_SWITCH)
core_dpll_param_3622:
/* 12MHz */
.word 100, 2, 0, 1
.word   0, 0, 0, 0
/* 13MHz */
.word 400, 12, 0, 1
.word   0,  0, 0, 0
/* 19.2MHz */
.word 375, 17, 0, 1
.word   0,  0, 0, 0
/* 26MHz */
.word 200, 12, 0, 1
.word   0,  0, 0, 0
/* 38.4MHz */
.word 375, 35, 0, 1
.word   0,  0, 0, 0
#endif


per_dpll_param:
#if defined(CONFIG_PER_M2_192)
/*	sys(kHz), m,	n,	clkin,	sd,	dco,	m2,	m3,	m4,	m5,	m6,	m2div */
.word 12000,	720,	4,	0,	7,	4,	9,	32,	10,	8,	6,	1
.word 13000,	864,	0,	1,	7,	4,	9,	32,	10,	8,	6,	1
.word 19200,	720,	7,	0,	7,	4,	9,	32,	10,	8,	6,	1
.word 26000,	864,	12,	0,	7,	4,	9,	32,	10,	8,	6,	1
.word 38400,	720,	15,	0,	7,	4,	9,	32,	10,	8,	6,	1
.word 0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0
#elif defined(CONFIG_PER_SGX_192)
/*	sys(kHz), m,	n,	clkin,	sd,	dco,	m2,	m3,	m4,	m5,	m6,	m2div */
.word 12000,	720,	4,	0,	7,	4,	9,	32,	10,	8,	6,	2
.word 13000,	864,	0,	1,	7,	4,	9,	32,	10,	8,	6,	2
.word 19200,	720,	7,	0,	7,	4,	9,	32,	10,	8,	6,	2
.word 26000,	864,	12,	0,	7,	4,	9,	32,	10,	8,	6,	2
.word 38400,	720,	15,	0,	7,	4,	9,	32,	10,	8,	6,	2
.word 0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0	
#else /* Default to 96 MHz M2 */
/*	sys(kHz), m,	n,	clkin,	sd,	dco,	m2,	m3,	m4,	m5,	m6,	m2div */
.word 12000,	360,	4,	0,	4,	2,	9,	16,	5,	4,	3,	1
.word 13000,	432,	0,	1,	4,	2,	9,	16,	5,	4,	3,	1
.word 19200,	360,	7,	0,	4,	2,	9,	16,	5,	4,	3,	1
.word 26000,	432,	12,	0,	4,	2,	9,	16,	5,	4,	3,	1
.word 38400,	360,	15,	0,	4,	2,	9,	16,	5,	4,	3,	1
.word 0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0	
#endif
