# Audio LPF generator for MiSTer 
#  -- adapted from original Matlab code written by Soltan_G42
#  -- python port by Newsdee

# NOTE: if missing, these packages can be installed via "pip install <package>" in cmd line
import numpy as np
from scipy import signal


#  suffix to .txt and .png files, set to '_py' to avoid overriding original filters
SUFFIX = '' 

# standard sampling rate of 7Mhz, used by most filters
SR_7MHZ = 7056000

# --------------------------------------------------------------------------- #

def write_filter(b, a, shortName, longName, fs):
    order = len(b)-1
    if order > 3:
        raise ValueError('Filter must be 3rd order or lower')
    if order < 1 or (len(b)!=len(a)):
        raise ValueErrro('Bad filter input')
    fname = shortName + ('%s.txt' % SUFFIX)
    print('%s (%s)' % (longName, fname))
    # --
    f = open(fname, 'w')
    # output version
    f.write('#Version\n')
    f.write('v1\n\n')
    # output original filename (short name)
    f.write('#Original Filename\n')
    f.write('#%s\n\n' % fname)
    # output description (long name)
    f.write('#Filter Description\n')
    f.write('#%s\n\n'%longName.strip())
    # output sample rate (FS)
    f.write('#Sampling Frequency\n')
    f.write(str(fs)+'\n\n')
    # output GAIN
    # Note that on this site: https://www-users.cs.york.ac.uk/~fisher/mkfilter/trad.html
    # GAIN seems to be always 1/min(b) from Soltan's local matlab/octave results
    f.write('#Base gain\n')
    gain = float(sum(b) * 1.39)
    f.write('%.20f\n\n' % gain)
    # output X coefficients. Zeros if filter is Order <3
    for i in range(1, 4):
        f.write('#gain scale for X%d\n'%(i-1))
        if i<=order:
            f.write('%d\n\n' % round(b[i]/min(b)))
        else:
            f.write('0\n\n')
    # output Y coefficients. Zeros if filter is order < 3
    for i in range(1, 4):
        f.write('#gain scale for Y%d\n'%(i-1))
        if i<=order:
            f.write('%.20f\n\n'% a[i])
        else:
            f.write('0\n\n')
    f.flush()
    f.close()
    return fname
    
# --------------------------------------------------------------------------- #

def addFilter( b, a, fname, fdesc, fs=SR_7MHZ):
    write_filter(b, a, fname, fdesc, fs=fs)
    leg_labels.append(fname)
    [w, h] = signal.freqz(b, a, freqs, fs=fs)
    tf.append( 20. * np.log10(abs(h)) ) # same as matlab's mag2db(abs(h))
    
def addSingleFilter(fname, fdesc, hz, order, ripple=None, fs=SR_7MHZ):
    Nyquist = fs/2.
    if ripple is None:
        [b, a] = signal.butter(order, hz/Nyquist)
    else:
        [b, a] = signal.cheby1(order, ripple, hz/Nyquist)
    addFilter(b, a, fname, fdesc, fs=fs)

def addCombinedFilter(fname, fdesc, hz1, hz2, fs=SR_7MHZ):
    '''combine 1st and 2nd order filters'''
    Nyquist = fs/2.
    [b1, a1] = signal.butter(1, hz1/Nyquist)
    [b2, a2] = signal.butter(2, hz2/Nyquist)
    b = np.convolve(b1, b2)
    a = np.convolve(a1, a2)
    addFilter(b, a, fname, fdesc, fs=fs)

def addMixedFilter(fname, fdesc, fs, hz1, hz2, ripple):
    '''combine 1st and 2nd order filters using Chebyshev as 2nd order'''
    # Not really useful according to Soltan_G42, but here if we want to graph it
    Nyquist = fs/2.
    [b1, a1] = signal.butter(1, hz1/Nyquist)
    [b2, a2] = signal.cheby1(2, ripple, hz2/Nyquist)
    b = np.convolve(b1, b2)
    a = np.convolve(a1, a2)
    addFilter(b, a, fname, fdesc, fs=fs)

# --------------------------------------------------------------------------- #
# main program

freqs = 2.* np.logspace(1, 5, 1001)
leg_labels = []
tf = []

# --------------------------------------------------------------------------- #

addSingleFilter("sample_a", "sample_a", 9685, 2, fs = 3579545)
addSingleFilter("sample_b", "sample_b", 10749, 2, fs = 3579545)
addCombinedFilter("sample_com", "sample_com", 10749, 9685, fs= 3579545)
addCombinedFilter("sample_c", "sample_c", 19020, 8707, fs = 3579545)
addCombinedFilter("sample_d", "sample_d", 8707, 19020, fs = 3579545)


# --------------------------------------------------------------------------- #

from matplotlib import pyplot as plt  # for graph output, can be removed (see end of file)

# Graph it all - this can be removed if you don't want graphs
fig, ax1 = plt.subplots()
plt.xscale('log')
ax1.set_title('MiSTer Audio Filter Response')
plt.ylim(-60, 1)     # limit Y to -60db
plt.xlim(20, 22050)  # chop off display at 22hz
for h in tf:
    ax1.plot(freqs, h)
ax1.legend(leg_labels, prop={'size': 8})
plt.grid(True, ls='--', color='gray', which='both', axis='both')
plt.savefig('Filter_Plots%s.png' % SUFFIX)
plt.savefig('Filter_Plots%s.pdf' % SUFFIX)

# EOF
