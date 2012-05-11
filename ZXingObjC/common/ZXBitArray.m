#import "ZXBitArray.h"

@interface ZXBitArray ()

@property (nonatomic, assign) int size;
@property (nonatomic, assign) int* bits;
@property (nonatomic, assign) int bitsLength;

- (void)ensureCapacity:(int)aSize;
- (int *)makeArray:(int)size;

@end

@implementation ZXBitArray

@synthesize bits;
@synthesize bitsLength;
@synthesize size;

- (id)init {
  if (self = [super init]) {
    self.size = 0;
    self.bits = (int*)malloc(1 * sizeof(int));
    self.bitsLength = 1;
    self.bits[0] = 0;
  }

  return self;
}

- (id)initWithSize:(int)aSize {
  if (self = [super init]) {
    self.size = aSize;
    self.bits = [self makeArray:aSize];
    self.bitsLength = (aSize + 31) >> 5;
  }

  return self;
}


- (void)dealloc {
  if (bits != NULL) {
    free(bits);
    bits = NULL;
  }

  [super dealloc];
}

- (int)sizeInBytes {
  return (self.size + 7) >> 3;
}

- (void)ensureCapacity:(int)aSize {
  if (aSize > self.bitsLength << 5) {
    int* newBits = [self makeArray:aSize];
    
    for (int i = 0; i < self.bitsLength; i++) {
      newBits[i] = self.bits[i];
    }

    if (self.bits != NULL) {
      free(self.bits);
      self.bits = NULL;
    }
    self.bits = newBits;
    self.bitsLength = (aSize + 31) >> 5;
  }
}


- (BOOL)get:(int)i {
  return (self.bits[i >> 5] & (1 << (i & 0x1F))) != 0;
}


- (void)set:(int)i {
  self.bits[i >> 5] |= 1 << (i & 0x1F);
}


/**
 * Flips bit i.
 */
- (void)flip:(int)i {
  self.bits[i >> 5] ^= 1 << (i & 0x1F);
}


/**
 * Sets a block of 32 bits, starting at bit i.
 * 
 * newBits is the new value of the next 32 bits. Note again that the least-significant bit
 * corresponds to bit i, the next-least-significant to i+1, and so on.
 */
- (void)setBulk:(int)i newBits:(int)newBits {
  self.bits[i >> 5] = newBits;
}


/**
 * Clears all bits (sets to false).
 */
- (void)clear {
  for (int i = 0; i < self.bitsLength; i++) {
    self.bits[i] = 0;
  }
}


/**
 * Efficient method to check if a range of bits is set, or not set.
 */
- (BOOL)isRange:(int)start end:(int)end value:(BOOL)value {
  if (end < start) {
    @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Start greater than end" userInfo:nil];
  }
  if (end == start) {
    return YES;
  }
  end--;
  int firstInt = start >> 5;
  int lastInt = end >> 5;

  for (int i = firstInt; i <= lastInt; i++) {
    int firstBit = i > firstInt ? 0 : start & 0x1F;
    int lastBit = i < lastInt ? 31 : end & 0x1F;
    int mask;
    if (firstBit == 0 && lastBit == 31) {
      mask = -1;
    } else {
      mask = 0;

      for (int j = firstBit; j <= lastBit; j++) {
        mask |= 1 << j;
      }
    }
    if ((self.bits[i] & mask) != (value ? mask : 0)) {
      return NO;
    }
  }

  return YES;
}

- (void)appendBit:(BOOL)bit {
  [self ensureCapacity:self.size + 1];
  if (bit) {
    self.bits[self.size >> 5] |= (1 << (self.size & 0x1F));
  }
  self.size++;
}


/**
 * Appends the least-significant bits, from value, in order from most-significant to
 * least-significant. For example, appending 6 bits from 0x000001E will append the bits
 * 0, 1, 1, 1, 1, 0 in that order.
 */
- (void)appendBits:(int)value numBits:(int)numBits {
  if (numBits < 0 || numBits > 32) {
    @throw [NSException exceptionWithName:NSInvalidArgumentException
                                   reason:@"Num bits must be between 0 and 32"
                                 userInfo:nil];
  }
  [self ensureCapacity:self.size + numBits];
  for (int numBitsLeft = numBits; numBitsLeft > 0; numBitsLeft--) {
    [self appendBit:((value >> (numBitsLeft - 1)) & 0x01) == 1];
  }
}

- (void)appendBitArray:(ZXBitArray *)other {
  int otherSize = [other size];
  [self ensureCapacity:self.size + otherSize];

  for (int i = 0; i < otherSize; i++) {
    [self appendBit:[other get:i]];
  }
}

- (void)xor:(ZXBitArray *)other {
  if (self.bitsLength != other->bitsLength) {
    @throw [NSException exceptionWithName:NSInvalidArgumentException
                                   reason:@"Sizes don't match"
                                 userInfo:nil];
  }

  for (int i = 0; i < self.bitsLength; i++) {
    self.bits[i] ^= other.bits[i];
  }
}


- (void)toBytes:(int)bitOffset array:(unsigned char *)array offset:(int)offset numBytes:(int)numBytes {
  for (int i = 0; i < numBytes; i++) {
    int theByte = 0;
    for (int j = 0; j < 8; j++) {
      if ([self get:bitOffset]) {
        theByte |= 1 << (7 - j);
      }
      bitOffset++;
    }
    array[offset + i] = (char)theByte;
  }
}

/**
 * Reverses all bits in the array.
 */
- (void)reverse {
  int *newBits = (int*)malloc(self.size * sizeof(int));
  for (int i = 0; i < self.size; i++) {
    newBits[i] = 0;
    if ([self get:self.size - i - 1]) {
      newBits[i >> 5] |= 1 << (i & 0x1F);
    }
  }

  if (self.bits != NULL) {
    free(self.bits);
  }
  self.bits = newBits;
}

- (int *)makeArray:(int)aSize {
  int arraySize = (aSize + 31) >> 5;
  int *newArray = (int*)malloc(arraySize * sizeof(int));
  for (int i = 0; i < arraySize; i++) {
    newArray[i] = 0;
  }
  return newArray;
}

- (NSString *)description {
  NSMutableString* result = [NSMutableString string];

  for (int i = 0; i < size; i++) {
    if ((i & 0x07) == 0) {
      [result appendString:@" "];
    }
    [result appendString:[self get:i] ? @"X" : @"."];
  }

  return [NSString stringWithString:result];
}

@end