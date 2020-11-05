#include <stdexcept>

#include <cstdio>
#include <cstdlib>

#include "sdramsim.h"

using namespace std;

uint16_t	SDRAMSIM::operator()(int clk, int cke, int cs_n, int ras_n, int cas_n, int we_n,
		int bs, unsigned addr, int driv, uint16_t data, uint16_t dqm) {
	uint16_t	result = 0;

	if (driv) // If the bus is going out, reads don't make sense ... but
		result = data; // read what we output anyway
	else if (!clk) // If the clock is zero, return our last value
		return m_last_value; // Always called w/clk=1, thus never here
	if (!cke) {
		fprintf(stderr, "This simulation only supports CKE high!\n");
		fprintf(stderr, "\tCKE   = %d\n", cke);
		fprintf(stderr, "\tCS_n  = %d\n", cs_n);
		fprintf(stderr, "\tRAS_n = %d\n", ras_n);
		fprintf(stderr, "\tCAS_n = %d\n", cas_n);
		fprintf(stderr, "\tWE_n  = %d\n", we_n);
		throw logic_error("This simulation only supports CKE high!");
	}

	if (m_pwrup < POWERED_UP_STATE) {
		if (dqm != 3) throw logic_error("invalid dqm before POWERED_UP_STATE");
		if (m_clocks_till_idle > 0)
			m_clocks_till_idle--;
		if (m_pwrup == 0) {
			if (!((ras_n)&&(cas_n)&&(we_n))) throw logic_error("keep ras_n/cas_n/we_n high during power up wait");
			if (m_clocks_till_idle == 0) {
				m_pwrup++;
				printf("Successful power up wait, moving to state #1\n");
			}
		} else if (m_pwrup == 1) {
			if ((!cs_n)&&(!ras_n)&&(cas_n)&&(!we_n)&&(addr&0x0400)) {
				// Wait until a precharge all banks command
				m_pwrup++;
				printf("Successful precharge command, moving to state #2\n");
				m_clocks_till_idle = 8;
			}
		} else if (m_pwrup == 2) {
			// Need 8 auto refresh cycles before or after the mode
			// set command.  We'll insist they be before.
			if (m_clocks_till_idle == 0) {
				m_pwrup++;
				printf("Successful initial auto-refresh, waiting for mode-set\n");
				for(int i=0; i<m_nrefresh; i++)
					m_refresh_time[i] = MAX_REFRESH_TIME;
			} 
			else if (!((!cs_n)&&(!ras_n)&&(!cas_n)&&(we_n)))
				throw logic_error("Expected 8 cycles in Auto refresh/Self-refresh mode");
		} else if (m_pwrup == 3) {
			const int tRSC = 2;
			if ((!cs_n)&&(!ras_n)&&(!cas_n)&&(!we_n)){
				// mode set
				printf("Mode set: %08x\n", addr);
				if(addr != 0x021) throw new logic_error("Unexpected addr during mode set");

				m_pwrup++;
				printf("Successful mode set, moving to state #3, tRSC = %d\n", tRSC);
				m_clocks_till_idle=tRSC;
			}
		} else if (m_pwrup == 4) {
			if(!cs_n)  throw new logic_error("CS_N pulled low too soon after mode set (tRSC violated)");
			if (m_clocks_till_idle == 0) {
				m_pwrup = POWERED_UP_STATE;
				m_clocks_till_idle = 0;
				printf("Successful setup!  SDRAM switching to operational\n");
			} else if (m_clocks_till_idle == 1) {
				;
			} else throw logic_error("Should never get here!");
		} else if (m_pwrup == 5) {
			if ((!cs_n)&&(!ras_n)&&(!cas_n)&&(we_n)) {
				if (m_clocks_till_idle == 0) {
					m_pwrup = POWERED_UP_STATE;
					m_clocks_till_idle = 0;

					for(int i=0; i<m_nrefresh; i++)
						m_refresh_time[i] = MAX_REFRESH_TIME;
				}
			} else {
				throw logic_error("Should never get here!");
			}
		}
		m_next_wr = false;
	} else { // In operation ...
		for(int i=0; i<m_nrefresh; i++)
			m_refresh_time[i]--;
		if (m_refresh_time[m_refresh_loc] < 0) {
			throw logic_error("Failed refresh requirement");
		} for(int i=0; i<NBANKS; i++) {
			m_bank_status[i] >>= 1;
			if (m_bank_status[i]&2)
				m_bank_status[i] |= 4;
			if (m_bank_status[i]&1) { // Bank is open
				m_bank_open_time[i] --;
				if (m_bank_open_time[i] < 0) {
					throw logic_error("Bank held open too long");
				}
			}
		}

		if (m_clocks_till_idle)
			m_clocks_till_idle--;

		if (m_fail > 0) {
			m_fail--;
			if (m_fail == 0) {
				throw logic_error("Failing on schedule");
				exit(-3);
			}
		}

		if ((m_clocks_till_idle > 0)&&(m_next_wr)) {
			// printf("SDRAM[%08x] <= %04x\n", m_wr_addr, data & 0x0ffff);
			int	waddr = m_wr_addr++, memval;
			if (waddr < 0 || waddr >= SDRAMSZB/2)
				throw logic_error("waddr out of bounds");
			memval = m_mem[waddr];
			if ((dqm&3)==0)
				memval = data;
			else if ((dqm&3)==3)
				;
			else if ((dqm&2)==0)
				memval = (memval & 0x000ff) | (data & 0x0ff00);
			else // if ((dqm&1)==0)
				memval = (memval & 0x0ff00) | (data & 0x000ff);
			m_mem[waddr] = memval;
			result = data;
			m_next_wr = false;
		}
		m_qloc = (m_qloc + 1)&m_qmask;
		result = (driv)?data:m_qdata[(m_qloc)&m_qmask];
		m_qdata[(m_qloc)&m_qmask] = 0;

		// if (result != 0)
		// 	printf("%d RESULT[%3d] = %04x\n", clk, m_qloc, result&0x0ffff);

		if ((!cs_n)&&(!ras_n)&&(!cas_n)&&(we_n)) {
			// Auto-refresh command
			m_refresh_time[m_refresh_loc] = MAX_REFRESH_TIME;
			m_refresh_loc++;
			if (m_refresh_loc >= m_nrefresh)
				m_refresh_loc = 0;
			if((m_bank_status[0]&6) != 0) throw logic_error("Trying to auto-refresh bank 0 when not in state 0");
			if((m_bank_status[1]&6) != 0) throw logic_error("Trying to auto-refresh bank 1 when not in state 0");
			if((m_bank_status[2]&6) != 0) throw logic_error("Trying to auto-refresh bank 2 when not in state 0");
			if((m_bank_status[3]&6) != 0) throw logic_error("Trying to auto-refresh bank 3 when not in state 0");
		} else if ((!cs_n)&&(!ras_n)&&(cas_n)&&(!we_n)) {
			if (addr&0x0400) {
				// Bank/Precharge All CMD
				for(int i=0; i<NBANKS; i++)
					m_bank_status[i] &= 0x03;
			} else {
				// Precharge/close single bank
				if((bs & (~3)) != 0)
					throw new logic_error("bs out of bounds");
				m_bank_status[bs] &= 0x03; // Close the bank

				printf("Precharging bank %d\n", bs);
			}
		} else if ((!cs_n)&&(!ras_n)&&(cas_n)&&(we_n)) {
			// printf("Activating bank %d\n", bs);
			// Activate a bank!
			if (0 != (bs & (~3))) {
				m_fail = 2;
				fprintf(stderr, "ERR: Activating a bank w/ more than 2 bits\n");
				// assert(0 == (bs & (~3))); // Assert w/in bounds
			} else if (m_bank_status[bs] != 0) {
				fprintf(stderr, "ERR: Status of bank [bs=%d] = %d != 0\n",
					bs, m_bank_status[bs]);
				m_fail = 4;
				// assert(m_bank_status[bs]==0); // Assert bank was closed
			}
			// fprintf(stderr, "Open Bank %X, addr %X\n", bs, addr);
			m_bank_status[bs] |= 4;
			m_bank_open_time[bs] = MAX_BANKOPEN_TIME;
			m_bank_row[bs] = addr;
		} else if ((!cs_n)&&(ras_n)&&(!cas_n)) {
			// printf("R/W Op\n");
			if (!we_n) {
				// Initiate a write
				if((bs & (~3)) != 0)
					throw new logic_error("bs out of bounds");
				if(!(m_bank_status[bs]&1)) throw new logic_error("Cannot r/w bank before opening");

				m_wr_addr = m_bank_row[bs];
				m_wr_addr <<= 2;
				m_wr_addr |= bs;
				m_wr_addr <<= 9;
				m_wr_addr |= (addr & 0x01ff);

				if (m_wr_addr < 0 || m_wr_addr >= SDRAMSZB/2) 
					throw logic_error("waddr out of bounds");

				if (!driv)
					throw new logic_error("Cannot write with driv low");

				// printf("SDRAM[%08x] <= %04x\n", m_wr_addr, data & 0x0ffff);
				m_mem[m_wr_addr++] = data;
				m_clocks_till_idle = 2;
				m_next_wr = true;

				if (addr & 0x0400) { // Auto precharge
					m_bank_status[bs] &= 3;
					m_bank_open_time[bs] = MAX_BANKOPEN_TIME;
				}
			} else { // Initiate a read
				if((bs & (~3)) != 0)
					throw new logic_error("bs out of bounds");
				if(!(m_bank_status[bs]&1)) throw new logic_error("Cannot r/w bank before opening");

				unsigned	rd_addr;

				rd_addr = m_bank_row[bs] & 0x01fff;
				rd_addr <<= 2;
				rd_addr |= bs;
				rd_addr <<= 9;
				rd_addr |= (addr & 0x01ff);

				if (driv) throw new logic_error("Cannot read with driv high");

				// printf("SDRAM.Q[%2d] %04x <= SDRAM[%08x]\n",
				// 	(m_qloc+3)&m_qmask,
				// 	m_mem[rd_addr] & 0x0ffff, rd_addr);
				if (rd_addr < 0 || rd_addr >= SDRAMSZB/2)
					throw logic_error("rd_addr out of bounds");
				m_qdata[(m_qloc+3)&m_qmask] = m_mem[rd_addr++];
				// printf("SDRAM.Q[%2d] %04x <= SDRAM[%08x]\n",
				// 	(m_qloc+4)&m_qmask,
				// 	m_mem[rd_addr] & 0x0ffff, rd_addr);
				if (rd_addr < 0 || rd_addr >= SDRAMSZB/2)
					throw logic_error("rd_addr out of bounds");
				m_qdata[(m_qloc+4)&m_qmask] = m_mem[rd_addr++];
				m_clocks_till_idle = 2;

				if (addr & 0x0400) { // Auto precharge
					m_bank_status[bs] &= 3;
					m_bank_open_time[bs] = MAX_BANKOPEN_TIME;
				}
			}
		} else if (cs_n) {
			// Chips not asserted, DESELECT CMD equivalent of a NOOP
		} else if ((ras_n)&&(cas_n)&&(we_n)) {
			// NOOP command
		} else {
			fprintf(stderr, "Unrecognized memory command!\n");
			fprintf(stderr, "\tCS_n  = %d\n", cs_n);
			fprintf(stderr, "\tRAS_n = %d\n", ras_n);
			fprintf(stderr, "\tCAS_n = %d\n", cas_n);
			fprintf(stderr, "\tWE_n  = %d\n", we_n);
			throw new logic_error("Unrecognized command");
		}
	}

	return result & 0x0ffff;
}


