l = [5,4,3,2,1]

def swap(x,y,l):
    v = l[x]
    l[x] = l[y]
    l[y] = v

swapped = True

while swapped:
    swapped = False
    i = 0
    while i < len(l)-1:
        if(l[i] > l[i + 1]):
            swap(i, i + 1, l)
            swapped = True
        i = i + 1

print(l)

