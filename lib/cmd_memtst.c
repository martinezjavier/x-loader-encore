
/*
 * Source:
 * http://www.esacademy.com/en/library/technical-articles-and-documents/miscellaneous/software-based-memory-testing.html
 *
 */

#include <common.h>
#include <command.h>

typedef unsigned char datum;    // Set the data bus width to 8 bits.

datum memTestDataBus(volatile datum *address);
datum *memTestAddressBus(volatile datum *baseAddress, unsigned long nBytes);
datum *memTestDevice(volatile datum *baseAddress, unsigned long nBytes, unsigned long step);

/**********************************************************************
 * Need to Add Signal Integrity Tests for DDR2/DDR3
 * For fast DDR2 and DDR3 memories doing Data bus, Address bus, and Device tests is not enough.
 * There is another class of problems related to the signal integrity issues between the
 * chip - processor or an FPGA - and the memory device.

 * 1. Board level signal integrity is tested by toggling as many bits as possible.
 * For example, writing and reading all-F and all-zero patterns.
 * That will reveal power supply and cross-talk issues

 * 2. Timing problems (setup and hold violations) are tested by running
 * a long random-access test and tweaking memory controller settings.
 ***********************************************************************/

int memTest(ulong addr, ulong length, ulong step)
{
    printf ("TESTING MEMORY, PLEASE WAIT!\n");

    if ((memTestDataBus((volatile unsigned char *)addr) != 0) ||
        (memTestAddressBus((volatile unsigned char *)addr, length) != NULL) ||
        (memTestDevice((volatile unsigned char *)addr, length, step) != NULL))
    {
	printf ("Memory Test Not Success !!!!!!!!!\n");
        return (-1);
    }
    else
    {
	printf ("Memory Test Success \n");
        return (0);
    }

}   /* memTest() */

/**********************************************************************
 *
 * Function:    memTestDataBus()
 *
 * Description: Test the data bus wiring in a memory region by
 *              performing a walking 1's test at a fixed address
 *              within that region.  The address (and hence the
 *              memory region) is selected by the caller.
 *
 * Notes:
 *
 * Returns:     0 if the test succeeds.
 *              A non-zero result is the first pattern that failed.
 *
 **********************************************************************/
datum memTestDataBus(volatile datum *address)
{
datum pattern;

    // Perform a walking 1's test at the given address.
    for (pattern = 1; pattern != 0; pattern <<= 1)
    {
        // Write the test pattern.
        *address = pattern;

        // Read it back (immediately is okay for this test).
        if (*address != pattern)
        {
            return (pattern);
        }
    }

    return (0);

}   // memTestDataBus()


/**********************************************************************
 *
 * Function:    memTestAddressBus()
 *
 * Description: Test the address bus wiring in a memory region by
 *              performing a walking 1's test on the relevant bits
 *              of the address and checking for aliasing. This test
 *              will find single-bit address failures such as stuck
 *              -high, stuck-low, and shorted pins.  The base address
 *              and size of the region are selected by the caller.
 *
 * Notes:       For best results, the selected base address should
 *              have enough LSB 0's to guarantee single address bit
 *              changes.  For example, to test a 64-Kbyte region,
 *              select a base address on a 64-Kbyte boundary.  Also,
 *              select the region size as a power-of-two--if at all
 *              possible.
 *
 * Returns:     NULL if the test succeeds.
 *              A non-zero result is the first address at which an
 *              aliasing problem was uncovered.  By examining the
 *              contents of memory, it may be possible to gather
 *              additional information about the problem.
 *
 **********************************************************************/
datum *memTestAddressBus(volatile datum *baseAddress, unsigned long nBytes)
{
unsigned long addressMask = (nBytes/sizeof(datum) - 1);
unsigned long offset;
unsigned long testOffset;

datum pattern     = (datum) 0xAAAAAAAA;
datum antipattern = (datum) 0x55555555;

    // Write the default pattern at each of the power-of-two offsets.
    for (offset = 1 ; (offset & addressMask) != 0 ; offset <<= 1)
    {
        baseAddress[offset] = pattern;
    }

    // Check for address bits stuck high.
    testOffset = 0;
    baseAddress[testOffset] = antipattern;

    for (offset = 1 ; (offset & addressMask) != 0 ; offset <<= 1)
    {
        if (baseAddress[offset] != pattern)
        {
	    printf("DRAM: %04ld MB Fail\n", offset/1024/1024);
            return ((datum *) &baseAddress[offset]);
        }
    }

    baseAddress[testOffset] = pattern;

    // Check for address bits stuck low or shorted.
    for (testOffset = 1 ; (testOffset & addressMask) != 0 ; testOffset <<= 1)
    {
        baseAddress[testOffset] = antipattern;

		if (baseAddress[0] != pattern)
		{
			printf("DRAM: %04ld MB Fail\n", offset/1024/1024);
			return ((datum *) &baseAddress[testOffset]);
		}

        for (offset = 1; (offset & addressMask) != 0; offset <<= 1)
        {
            if ((baseAddress[offset] != pattern) && (offset != testOffset))
            {
		printf("DRAM: %04ld MB Fail\n", offset/1024/1024);
                return ((datum *) &baseAddress[testOffset]);
            }
        }

        baseAddress[testOffset] = pattern;
    }

    return (NULL);
}   // memTestAddressBus()


/**********************************************************************
 *
 * Function:    memTestDevice()
 *
 * Description: Test the integrity of a physical memory device by
 *              performing an increment/decrement test over the
 *              entire region.  In the process every storage bit
 *              in the device is tested as a zero and a one.  The
 *              base address and the size of the region are
 *              selected by the caller.
 *
 * Notes:
 *
 * Returns:     NULL if the test succeeds.
 *
 *              A non-zero result is the first address at which an
 *              incorrect value was read back.  By examining the
 *              contents of memory, it may be possible to gather
 *              additional information about the problem.
 *
 **********************************************************************/
datum *memTestDevice(volatile datum *baseAddress, unsigned long nBytes, unsigned long step)
{
unsigned long offset, pi;
unsigned long nWords = nBytes / sizeof(datum);

datum pattern;
datum antipattern;

    // Fill memory with a known pattern.
    for (pattern = 1, offset = 0; offset < nWords; pattern++, offset += step)
    {
        baseAddress[offset] = pattern;
    }

    //    Check each location and invert it for the second pass.
    for (pattern = 1, offset = 0; offset < nWords; pattern++, offset += step)
    {
        if (baseAddress[offset] != pattern)
        {
	    printf("DRAM: %04ld MB Fail\n", offset/1024/1024);
            return ((datum *) &baseAddress[offset]);
        }

        antipattern = ~pattern;
        baseAddress[offset] = antipattern;
    }

    pi = 0;
    // Check each location for the inverted pattern and zero it.
    for (pattern = 1, offset = 0; offset < nWords; pattern++, offset += step)
    {
        antipattern = ~pattern;
        if (baseAddress[offset] != antipattern)
        {
	    printf("DRAM: %04ld MB Fail\n", offset/1024/1024);
            return ((datum *) &baseAddress[offset]);
        }
	if (pi++ >= (1<<20)) {
		pi = 0;
		printf("DRAM: %04ld MB OK\r", offset/1024/1024+1);
	}
    }
    printf("\n");

    return (NULL);

}   // memTestDevice()
