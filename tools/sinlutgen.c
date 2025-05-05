// Example sine lut generator
#include <stdio.h>
#include <math.h>

#define SIN_SIZE 256
#define SIN_FP 7

int main(int argc, char *argv[])
{
    int ii;
		FILE *fp;
		if (argc > 1)
			fp = fopen(argv[1], "w");
		else {
			printf("please specify a file\n");
			return 1;
		}
    unsigned char hw;

    fprintf(fp, ";\n; Sine lut; %d entries, %d fixeds\n;\n\n", 
        SIN_SIZE+64, SIN_FP);
    fprintf(fp, ".RODATA\n.align $100\nsinlut:\n");
    for(ii=0; ii<SIN_SIZE+64; ii++)
    {
        hw= (char)(sin(ii*2*M_PI/SIN_SIZE)*(1<<SIN_FP));
        if(ii%8 == 0)
            fputs("\n.byte ", fp);
				if (ii%8 == 7)
					fprintf(fp, "$%02X", hw);
				else
					fprintf(fp, "$%02X, ", hw);
    }
    /*
    fprintf(fp, "\n\n.align $100\nsinluth:\n");
    for(ii=0; ii<SIN_SIZE+64; ii++)
    {
        hw= (unsigned short)(sin(ii*2*M_PI/SIN_SIZE)*(1<<SIN_FP)) >> SIN_FP;
        if(ii%8 == 0)
            fputs("\n.byte ", fp);
				if (ii%8 == 7)
					fprintf(fp, "$%02X", hw);
				else
					fprintf(fp, "$%02X, ", hw);
    }
    */

    fclose(fp);
    return 0;
}