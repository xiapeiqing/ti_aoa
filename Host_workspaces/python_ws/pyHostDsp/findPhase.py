#!/usr/bin/python

# Example (make sure findPhase.py is executable and is in the current directory):
# $ ./findPhase.py

import numpy as np
import sys
#####################################################################################


def find_phase_rgression(d,phstruth):

  # Find frequency
  D = np.abs(np.fft.fftshift(np.fft.fft(d * np.hamming(len(d)))))
  
  f = np.arange(-0.5, 0.5-1.0/len(d), 1.0/len(d))
  pos = D.argmax()

  # Create x (synthetic sin wave)
  x = np.sin(2*np.pi*np.arange(-1,len(D))*np.abs(f[pos]))
  

  # Compute w
  w = LS_local(d,x,2)

  # Initialize
  ph0 = 0
  ph1 = -2*np.pi*np.abs(f[pos])

  # Compute ph
  ph = np.arctan( (w[0]*np.sin(ph0) + w[1]*np.sin(ph1)) / (w[0]*np.cos(ph0) + w[1]*np.cos(ph1)) )
  if np.sign((w[0]*np.cos(ph0) + w[1]*np.cos(ph1))) < 0:
    ph = ph - np.pi

  # Adjust ph (-pi < ph <= pi)
  while ph <= -np.pi:
    ph = ph + 2*np.pi
  while ph > np.pi:
    ph = ph - 2*np.pi

  # Adjust phstruth (-pi < phstruth <= pi)
  while phstruth <= -np.pi:
    phstruth = phstruth + 2*np.pi
  while phstruth > np.pi:
    phstruth = phstruth - 2*np.pi

  # Check
  print(str(phstruth) + " = " + str(ph) + " ?")   # These should be (approximately) equal or off by an integer multiple of 2*pi

  # Return
  return ph

#####################################################################################

def LS_local(d,x,Lw):

  # Initialize
  d = d.astype('double')
  x = x.astype('double')

  # Initialize
  Ld = len(d)
  Lx = len(x)
  print(Lx)

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
    findPhaseRegression(np.sin(2*np.pi*np.arange(1000)/100 + np.pi/12*c),np.pi/12*c)
