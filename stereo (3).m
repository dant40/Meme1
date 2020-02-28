
leftImage = imread("teddyL.pgm");
rightImage = imread("teddyR.pgm");
groundTruth = imread("disp2.pgm");

rankTImgL = zeros(375,450);
rankTImgR = zeros(375,450);
D1 = zeros(375,450);
D2 = zeros(375,450);
% get rank transform of both images
for Row = 1:375
    for Col = 1:450
        
        r1 = 0;
        r2 = 0;
        for i = -2:2
            for j = -2:2
                if(Row + j > 0 && Row + j <= 375 && Col + i > 0 && Col + i <= 450)
                    if(leftImage(Row + j, Col + i) < leftImage(Row,Col))
                        r1 = r1 + 1;
                    end
                     
                    if(rightImage(Row + j, Col + i) < rightImage(Row,Col))
                        r2 = r2 + 1;
                    end
                end
                
            end
        end
        
        
        rankTImgL(Row,Col) = r1; 
        rankTImgR(Row,Col) = r2;
  
    end
end

% lImage = mat2gray(rankTImgL);
% rImage = mat2gray(rankTImgR);
Cost1 = zeros(375,450,64);
Cost2 = zeros(375,450,64);

for Row = 1:375
    for Col = 1:450
        %SAD1 = 1:64;
        % still need this for 15x15 window
        for d = 0:63 
            sum1 = 0;         
            sum2 = 0;
            for i = -2:2
               for j = -2:2
                  if(Row + j > 0 && Row + j <= 375  && Col + i + (d) <= 375 && Col + i > 0 )
                      sum1 = sum1 +  abs(rankTImgR(Row + j, Col+ i) - rankTImgL(Row +j , Col + i + (d))) ;
                  end
               end  
            end
            
             for i = -7:7
               for j = -7:7
                  if(Row + j > 0 && Row + j <= 375  && Col + i + (d) <= 375 && Col + i > 0 )
                      sum2 = sum2 +  abs(rankTImgR(Row + j, Col+ i) - rankTImgL(Row +j , Col + i + (d))) ;
                  end
               end  
            end
            
            
            Cost1(Row,Col,d+1) = sum1;
            Cost2(Row,Col,d+1) = sum2;
        end
        
        [val1,index] =  min(Cost1(Row,Col,:));      
        D1(Row,Col) = index ;
        [val2,index] =  min(Cost2(Row,Col,:));      
        D2(Row,Col) = index ;
    end
end


dmap1 = mat2gray(D1);
dmap2 = mat2gray(D2);
imshow(dmap1);
imshow(dmap2)

quarterdisp2= round(groundTruth ./ 4);





        
