#!/usr/bin/python

# Example (make sure findPhase.py is executable and is in the current directory):
# $ ./findPhase.py

import numpy as np
import sys
import matplotlib.pyplot as plt
#####################################################################################



def phs_est_adaptive_filter(data):
    iqresult = [0,0]
    for iqSelection in range(2):
        data_one_arm = data[iqSelection:len(data):2]
        phs_est = find_phase_regression(data_one_arm)
        iqresult[iqSelection] = phs_est

    #return modmPitoPi(iqresult[0] - iqresult[1] + np.pi/2)
    return modmPitoPi((iqresult[0] + (iqresult[1] - np.pi/2))/2)


def find_phase_regression(d, phs_truth=""):

    print(np.mean(d))
    plt.use('Agg')
    plt.plot(d)
    plt.ylabel('some numbers')
    plt.show()
    # Find frequency
    D = np.abs(np.fft.fftshift(np.fft.fft(d * np.hamming(len(d)))))

    f = np.arange(-0.5, 0.5-1.0/len(d), 1.0/len(d))
    pos = D.argmax()

    # Create x (synthetic sin wave)
    x = np.sin(2*np.pi*np.arange(-1,len(D))*np.abs(f[pos]))


    # Compute w
    w = LS_local(np.asarray(d),x,2)

    # Initialize
    ph0 = 0
    ph1 = -2*np.pi*np.abs(f[pos])

    # Compute ph
    ph = np.arctan( (w[0]*np.sin(ph0) + w[1]*np.sin(ph1)) / (w[0]*np.cos(ph0) + w[1]*np.cos(ph1)) )
    if np.sign((w[0]*np.cos(ph0) + w[1]*np.cos(ph1))) < 0:
        ph = ph - np.pi

    ph = modmPitoPi(ph)



    if phs_truth: # determine Empty String
        phs_truth = modmPitoPi(phs_truth)
        # Check
        print(str(phs_truth) + " = " + str(ph) + " ?")     # These should be (approximately) equal or off by an integer multiple of 2*pi
    else:
        #print(str(ph))
        pass
    # Return
    return ph, ErrStd


def modmPitoPi(phs):
    # Adjust phs_truth (-pi < phs_truth <= pi)
    while phs <= -np.pi:
        phs = phs + 2*np.pi
    while phs > np.pi:
        phs = phs - 2*np.pi
    return phs

def LS_local(d,x,Lw):

    # Initialize
    d = d.astype('double')
    x = x.astype('double')

    # Initialize
    Ld = len(d)
    Lx = len(x)
    #print(Lx)

    # Check
    if Lx != (Ld + Lw - 1):
        raise Exception('Length of x or length of d is incorrect.')

    # Build R
    xx = np.zeros((Lw,Ld))+1
    #print(xx)
    for i in range(Lw):
        xx[i] = x[Lw-i-1:Lw-i-1+Ld]
    R = np.dot(xx, xx.transpose())

    # Build p
    p = np.dot(d, xx.transpose())

    # Compute w
    w = np.dot(np.linalg.inv(R), p.transpose())

    return w

#####################################################################################

# Main
if __name__ == '__main__':
    for c in np.arange(24):
        find_phase_regression(np.sin(2*np.pi*np.arange(1000)/100 + np.pi/12*c),np.pi/12*c)
