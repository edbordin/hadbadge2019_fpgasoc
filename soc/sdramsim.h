#ifndef	SDRAMSIM_H

#include <cstdlib>
#include <stdexcept>

#define	NBANKS	4
#define	POWERED_UP_STATE	6
// #define	CLK_RATE_HZ		100000000 // = 100 MHz = 100 * 10^6
#define	CLK_RATE_HZ		48000000 // = 100 MHz = 100 * 10^6
#define	PWRUP_WAIT_CKS		((int)(.000200 * CLK_RATE_HZ))

// #define	MAX_BANKOPEN_TIME	((int)(.000100 * CLK_RATE_HZ) ) // == 100 us
#define	MAX_BANKOPEN_TIME	((int)(.064 * CLK_RATE_HZ)) // == 64 ms
#define	MAX_REFRESH_TIME	((int)(.064 * CLK_RATE_HZ)) // == 64 ms

#define	SDRAM_QSZ		16

#define	LGSDRAMSZB	24
#define	SDRAMSZB	(1<<LGSDRAMSZB)

class	SDRAMSIM {
	int	m_pwrup;
	short	*m_mem;
	short	m_last_value, m_qmem[4];
	int	m_bank_status[NBANKS];
	int	m_bank_row[NBANKS];
	int	m_bank_open_time[NBANKS];
	unsigned	*m_refresh_time;
	int		m_refresh_loc, m_nrefresh;
	int	m_qloc, m_qdata[SDRAM_QSZ], m_qmask, m_wr_addr;
	int	m_clocks_till_idle;
	bool	m_next_wr;
	unsigned	m_fail;
public:
	SDRAMSIM(void) {
		m_mem = new short[SDRAMSZB/2]; // 32 MB, or 16 Mshorts

		m_nrefresh = 1<<13;
		m_refresh_time = new unsigned[m_nrefresh];
		for(int i=0; i<m_nrefresh; i++) {
			m_refresh_time[i] = 0;
		}
		for(int i=0; i<NBANKS; i++) {
			m_bank_open_time[i] = 0;
			m_bank_row[i] = 0;
			m_bank_status[i] = 0;
		}

		m_refresh_loc = 0;

		m_pwrup = 0;
		m_clocks_till_idle = 0;

		m_last_value = 0;
		m_clocks_till_idle = PWRUP_WAIT_CKS;
		m_wr_addr = 0;

		m_qloc  = 0;
		m_qmask = SDRAM_QSZ-1;

		m_next_wr = true;
		m_fail = 0;
	}

	~SDRAMSIM(void) {
		delete m_mem;
	}

	short operator()(int clk, int cke,
			int cs_n, int ras_n, int cas_n, int we_n, int bs, 
				unsigned addr,
			int driv, short data, short dqm);
	int	pwrup(void) const { return m_pwrup; }

	void	load(unsigned addr, const char *data, size_t len) {
		short		*dp;
		const char	*sp = data;
		unsigned	base;

		if((addr&1)!=0) throw new std::logic_error("Address misaligned");
		base = addr & (SDRAMSZB-1);
		if((len&1)!=0) throw new std::logic_error("Length misaligned");
		if(addr + len >= SDRAMSZB) throw new std::logic_error("Cannot load past end of memory");
		dp = &m_mem[(base>>1)];
		for(unsigned k=0; k<len/2; k++) {
			short	v;
			v = (sp[0]<<8)|(sp[1]&0x0ff);
			sp+=2;
			*dp++ = v;
		}
	}

	int load_file(const char *file, int offset) {
		FILE *f=fopen(file, "rb");
		if (f==NULL) {
			perror(file);
			exit(1);
		}
		int size=fread(&m_mem[offset], 1, SDRAMSZB-offset, f);
		fclose(f);
		printf("Loaded file %s to 0x%X - 0x%X\n", file, offset, offset+size);
		return 0;
	}
};

#endif
