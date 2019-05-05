// https://gist.github.com/kohyama/5260703
// gcc CRC8LUT.c -o CRC8LUT
#include <stdio.h>
#include <stdbool.h>
#include <limits.h>     // CHAR_BIT

// 記号定数
#define MSB_CRC8    (0x31)      // x8 + x5 + x4 + x0

// CRC8テーブルの初期化
static void InitCRC8Table( unsigned char table[256] )
{
    unsigned char value;
    int i, n;
    
    for (n = 0 ; n < 256 ; n++ ){
        value = (unsigned char)(n << (8 - CHAR_BIT));   // value = n;
        
        for ( i = 0 ; i < CHAR_BIT ; i++ ){
            if ( value & 0x80 ){
                value <<= 1; value ^= MSB_CRC8;
            }
            else{
                value <<= 1;
            }
        }
        table[ n ] = value;
    }
}

// CRC8テーブルの表示
static void ListCRC8Table( unsigned char table[256], bool bHexDisplay )
{
    unsigned char *p = table;
    int i, j, k;
    
    printf( "static unsigned char CRC8Table[ 256 ] = {\n" );
    for ( k = 3 ; k >= 0 ; k-- ){
        for ( j = 0 ; j < 8 ; j++ ){
            for ( i = 0 ; i < 8 ; i++ ){
                printf( (i == 0) ? "\t" : " " );
		if (bHexDisplay)
	            printf( "0x%02X,", *p++ );
		else
		    printf( "%03d,", *p++ );
            }
            if (bHexDisplay)
                printf( "\n" );
	    else
	        printf( " ...\n" );

        }
        //if ( k != 0 ) printf( "\t\n" );
    }
    printf( "};\n" );
}

// メイン関数
int main( void )
{
    unsigned char table[ 256 ];
    
    InitCRC8Table( table );
    ListCRC8Table( table, true );
    ListCRC8Table( table, false );

    return 0;
}
