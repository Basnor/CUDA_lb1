#include <stdio.h>
#include <math.h>
#include <time.h>
#include <stdlib.h>


unsigned int N = 1;
unsigned int S = 4;
unsigned int D = 3;

// среднее для скользящего окна
__global__ void add(double *inputArr, double *outputArr, int inputSize, int outputSize) {
    int col = threadIdx.x;
    int row = blockIdx.x;

    //printf("%d, %d \n", col,row);

    int result = 0;

    for (int k = row*2; k < row*2+4; k++) {
        for (int m = col*2; m < col*2+4; m++) {
            result += inputArr[k*inputSize + m];
           // if (col == 1 && row == 1) printf("%d, %d: %f, %d \n",row,col, inputArr[k*inputSize + m], k*inputSize+m);

        }
    }

    outputArr[row*(outputSize) + col] = result / 16;
    //printf("%f, \n", result/16);


}

void fillRandArr(double *Arr, int powD, int powS){
    for (int i = 0; i < powD; i++) {
        for (int j = 0; j < powS; j++) {
            int tmp = rand() % 100; // допустим не больше 100
            Arr[i*powS + j] = tmp;
            printf("%d, ", (int)Arr[i*powS + j]);
        }

        printf("\n");
    }

    printf("\n");

}

void formExpandedArr(double *inputArr, double *expandedArr, int powD, int powS){

    // верх лево
    expandedArr[0] = inputArr[0];
    // верх
    for (int j = 1; j < powS + 1; j++) {
        expandedArr[j] = inputArr[j-1];
    }
    // верх право
    expandedArr[powS + 1] = inputArr[powS-1];
    // право
    for (int i = 1; i < powD + 1; i++) {
        expandedArr[i*(powS + 2) + powS + 1] = inputArr[(i-1)*powS + powS-1];
    }
    // низ право
    expandedArr[(powS + 2)*(powD + 1) + powS + 1] = inputArr[powS*(powD-1) + powS-1];
    // низ
    for (int j = 1; j < powS + 1; j++) {
        expandedArr[(powS + 2)*(powD + 1) + j] = inputArr[(powS)*(powD-1) + j-1];
    }
    // низ лево
    expandedArr[(powD + 1)*(powS + 2)] = inputArr[(powD-1)*powS];
    // лево
    for (int i = 1; i < powD + 1; i++) {
        expandedArr[i*(powS + 2)] = inputArr[(i-1)*powS];
    }
    //центр
    for (int i = 1; i < powD + 1; i++) {
        for (int j = 1; j < powS + 1; j++) {
           expandedArr[i*(powS + 2) + j] = inputArr[(i-1)*powS + j-1];
        }
    }

}

void printArr(double *arr, int powD, int powS){
    for (int i = 0; i < powD; i++) {
        for (int j = 0; j < powS; j++) {
            printf("%d, ", (int)arr[i*powS+j]);
        }

        printf("\n");
    }

    printf("\n");
}

void printVerificationArr(double *expandedArr, int powDres, int powSres, int powS){
    double ArrResultCh[powDres*powSres]; // конечный

    for (int i = 0; i < powDres; i++) {
        for (int j = 0; j < powSres; j++) {

        int result = 0;

        for (int k = i*2; k < i*2+4; k++) {
                for (int m = j*2; m < j*2+4; m++) {
                    result += expandedArr[k*(powS + 2) + m];
                }
            }

            ArrResultCh[i*powSres + j] = result / 16;
            printf("%d, ", (int)ArrResultCh[i*powSres + j]);
        }

        printf("\n");
    }
}

int main(void) {
    srand(time(NULL));

    double *dev_i, *dev_o;

    int powD = (int)(pow( 2.0, (double)D ));
    int powS = (int)(pow( 2.0, (double)S ));

    int powDres = (int)(pow( 2.0, (double)(D - 1) ));
    int powSres = (int)(pow( 2.0, (double)(S - 1) ));

    //Выделить память на GPU
    cudaMalloc( (void**)&dev_i,
                   (powD + 2) * (powS + 2) * sizeof(double) );
    cudaMalloc( (void**)&dev_o,
                   powDres * powSres * sizeof(double) );


    double ArrM[powD*powS]; // начальный массив М
    fillRandArr(ArrM, powD, powS);


    while (N > 0) {


        double ArrMPlus[(powD + 2) * (powS + 2)]; // начальный массив М с добавлением крайних рядов
        formExpandedArr(ArrM, ArrMPlus, powD, powS);
        printArr(ArrMPlus, powD+2, powS+2);


        //Копируем массив ArrMPlus в dev_i
        cudaMemcpy( dev_i, ArrMPlus,
                              (powD + 2) * (powS + 2) * sizeof(double),
                              cudaMemcpyHostToDevice );

        add<<<powDres, powSres>>>(dev_i, dev_o, powS+2, powSres);
        cudaDeviceSynchronize();


        double ArrResult[powDres * powSres]; // конечный
        //Копируем массив с GPU на CPU
        cudaMemcpy( ArrResult, dev_o, powDres * powSres * sizeof(double), cudaMemcpyDeviceToHost );

        printArr(ArrResult, powDres, powSres);
        printVerificationArr(ArrMPlus, powDres, powSres, powS);


        D--;
        S--;
        powD = powDres;
        powS = powSres;
        powDres = (int)(pow( 2.0, (double)(D - 1) ));
        powSres = (int)(pow( 2.0, (double)(S - 1) ));

        for (int i = 0; i < powD; i++) {
            for (int j = 0; j < powS; j++) {
                ArrM[i*powS + j] = ArrResult[i*powS + j];
            }
        }

        printf("New Array:\n");
        printArr(ArrM, powD, powS);


        N--;
    }

    cudaFree( dev_i );
    cudaFree( dev_o );

    return 0;
}