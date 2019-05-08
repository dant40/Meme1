//Dan Thek , Jason Tran
//I pledge my honor that I have abided by the stevens honor system.
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <iostream>
#include <fstream>

using namespace std;

bool prepage = false;
int aType = 0;
int pageSize = 0;
int pageFaults = 0;
//unsigned long int globalTime =0;

typedef struct pages{
     unsigned long int pageNum;
     bool validBit;
     //this value is really relative time since last access
     unsigned long int accessTime = 0;
     int R = 1;
} page;



int main(int argc, char* argv[]){

     if (argc !=  6){
		fprintf(stderr, "Wrong number of command-line arguments\n Expecting: usage plist ptrace pagesize type flag\n");
		return(-1);
          }
     //get arguments passed in
     ifstream plist(argv[1]);
     ifstream ptrace(argv[2]);
     pageSize = stoi(argv[3]);
     if (pageSize > 32) pageSize =32;
     if(strcmp(argv[4],"FIFO")==0) aType = 1;
     else if(strcmp(argv[4],"LRU")==0) aType = 2;
     else aType = 3;
    // printf("aType is %i\n", aType);
     if (strcmp(argv[5],"+")==0) prepage = true;
     
   //  cout<< prepage <<endl;

     string line;
     int lineCount = 0;
     int tSizes[200];
     string token;

     //makes sure the files are at the start
     plist.clear();
     plist.seekg(0, ios::beg);
     ptrace.clear();
     ptrace.seekg(0,ios::beg);
     //traverse plist to find the sizes of each program and the amount of programs
     while(getline(plist,line)){
         if(!(line.length()<=1)){
               lineCount++;

               int temp = line.find(" ");
               token = line.substr(temp+1);
              // fprintf(stdout,"in line %s \ntemp is:%d\n %s\n",line,temp,token);
              //ceiling
               tSizes[lineCount-1] = 1 +((stoi(token)-1)/pageSize);
          }
     }
     plist.close();

     //list of page tables which themselves are lists of struct pointers
     page** pageTables[lineCount];
     //create a page table for each program (list of page struct pointers)
     page** pageTable;
     int count = 0;
     unsigned long int pNumCount = 0;
     page* curr;

     //default loading of memory
     //load this amount (or max) into each table by switching the valid bit to 1
     int numAddresses = 512/lineCount/pageSize;
     int maxPages = 512/pageSize;
     int index = 0;
     page* cached[maxPages];
     for(int i = 0; i < maxPages; i++){
          cached[i] = NULL;
     }
     //fprintf(stdout,"%d\n",numAddresses);

     while(tSizes[count] != 0){
          int temp = tSizes[count];
          if(temp > 0)
          pageTable = new page*[temp];
          for(int i =0; i < temp; i++){
               //initliaze every page within
               curr = new page;
               curr -> pageNum = pNumCount;
               if(i< numAddresses){
                    //in clock
                    index = index % maxPages;
                    cached[index] = curr;
                    curr -> validBit = true;
                    index++;
               }
               //not in memory
               else curr-> validBit = false;
               pNumCount++;
               pageTable[i] = curr;
          }
          //add it to the list of pagetables
          pageTables[count] = pageTable;
          count++;
     }
    // fprintf(stdout,"Got here before ptrace\n");
     string token2;
     string token3;
      
      index = 0;
     while(getline(ptrace,line)){
          if(!(line.length()<=1)){
               int temp = line.find(" ");
               token2 = line.substr(0,temp);
               token3 = line.substr(temp+1);
               int tableVal = stoi(token2);
               //ceiling
               int pageVal = 1+((stoi(token3)-1)/pageSize);
               page* curr = pageTables[tableVal][pageVal-1];
               page** currTable = pageTables[tableVal];
               if(curr->validBit == true) curr -> accessTime = 0;
               //not in memory
               if((curr -> validBit)==false){
                    //swap here based on algorithm
                    //FIFO
                    if(aType == 1){
                         index = index%maxPages;
                         if(cached[index] != NULL)
                              cached[index] -> validBit = false;
                         cached[index%maxPages] = curr;
                         curr -> validBit = true;
                         index++;
                         if(prepage == true){
                              int n = pageVal-1;
                              bool flag = false;
                              while(n <tSizes[tableVal]-1){
                                   if(currTable[n]-> validBit == false){
                                        break;
                                   }
                                   else {
                                        n++;
                                        if(!currTable[n]){
                                             n = 0;
                                             flag =true;
                                        }
                                        
                                   }
                                   if(flag && n == (pageVal-1)) break;
                              }
                              page* next  = currTable[n]; 
                              index = index%maxPages;
                              if(cached[index] != NULL)
                                   cached[index] -> validBit = false;    
                              cached[index%maxPages] = next;
                              next -> validBit = true;
                              index++;
                         }

                         pageFaults++;
                    }

                    //LRU
                    else if (aType == 2){
                        //everytime we go through check the curr page (even if it is in memory)
                       //set accessTime to 0 , otherwise increase accessTime
                       //when swaps do occur, throw out the one with the highest accessTime
                            //traverse currTable
                         int s = tSizes[tableVal];
                         int max = 0;
                         int maxIndex = 0;
                         //traverse currTable, and switch off the bit with the highest "accessTime"
                         //access time here is really just used as page "age"
                         for(int i = 0; i < s;i++){
                                   if(currTable[i]->validBit == true){
                                        if (currTable[i] -> accessTime > max){
                                             max = currTable[i] -> accessTime;
                                             maxIndex = i;
                                             }
                                        currTable[i] -> accessTime++;
                                        }
                         }
                         currTable[maxIndex] -> validBit = false;
                         curr -> validBit = true;
                         curr -> accessTime = 0;
                          //actual prepaging part adds the next page too
                         if(prepage == true){
                              int s = tSizes[tableVal];
                              int max = 0;
                              int maxIndex = 0;
                              for(int i = 0; i < s;i++){
                                        if(currTable[i]->validBit == true){
                                             if (currTable[i] -> accessTime > max){
                                                  max = currTable[i] -> accessTime;
                                                  maxIndex = i;
                                             }
                                         currTable[i] -> accessTime++;
                                        }
                              }
                              currTable[maxIndex] -> validBit = false;
                            //  currTable[maxIndex] -> accessTime = 0;
                              //get next page not in memory after curr
                              int n = pageVal-1;
                              bool flag = false;
                              while(n <tSizes[tableVal]-1){
                                   if(currTable[n]-> validBit == false){
                                        break;
                                   }
                                   else {
                                        n++;
                                        if(!currTable[n]){
                                             n = 0;
                                             flag =true;
                                        }
                                        
                                   }
                                   if(flag && n == (pageVal-1)) break;
                              }
                              page* next  =currTable[n];
                              next -> validBit = true;
                              next -> accessTime = 0;
                         }
                         pageFaults++;
                    }

                    //CLOCK
                    else if (aType == 3){


                        //fprintf(stdout,"In clock\n");
                         //Just does exactly whats described in the slides
                         index = index % maxPages;
                         while(cached[index] != NULL){
                              index = index % maxPages;
                              if(cached[index] -> R == 0){
                                   cached[index] -> validBit = false;
                                   cached[index] = curr;
                                   cached[index] -> R = 1;
                                   cached[index] -> validBit = true;
                                   index++;
                                   break;
                              }
                              else{
                                   cached[index] -> R = 0;
                                   index++;
                              }
                         }
                         if(cached[index] == NULL){
                              cached[index] = curr;
                              cached[index] -> R = 1;
                              cached[index] -> validBit = true;
                              index++;
                         }
                          if(prepage){
                              int n = pageVal-1;
                              bool flag = false;
                              while(n <tSizes[tableVal]-1){
                                   if(currTable[n]-> validBit == false){
                                        break;
                                   }
                                   else {
                                        n++;
                                        if(!currTable[n]){
                                             n = 0;
                                             flag =true;
                                        }
                                        
                                   }
                                   if(flag && n == (pageVal-1)) break;
                              }
                              
                              page* next  =currTable[n];
                              index = index % maxPages;
                              while(cached[index] != NULL){
                                   index = index % maxPages;
                                   if(cached[index] -> R == 0){
                                        cached[index] -> validBit = false;
                                        cached[index] = next;
                                        cached[index] -> R = 1;
                                        cached[index] -> validBit = true;
                                        index++;
                                        break;
                                   }
                                   else{
                                        cached[index] -> R = 0;
                                        index++;
                                   }
                              }
                              if(cached[index] == NULL){
                                   cached[index] = next;
                                   cached[index] -> R = 1;
                                   cached[index] -> validBit = true;
                                   index++;
                              }

                         }
                         pageFaults++;
                    }

                 //  fprintf(stdout,"Page fault occured at %d\n",pageVal-1);
                    }
          }
     }
     fprintf(stdout,"Number of page faults: %d\n", pageFaults);
     ptrace.close();

}
