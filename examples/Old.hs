-- Stream Generators for QuickCheck

module SampleStreamsQC where

------------------------------------------------------------------------------
import Test.QuickCheck

import FRP.Yampa as Yampa
import FRP.Yampa.Stream
import SampleStreams

-- ** Generators
positiveSignalStream (a,as) = all (>0) $ map fst as

instance Arbitrary a => Arbitrary (TimedSample a) where
  arbitrary = do
    x <- arbitrary
    Positive dt <- arbitrary
    return (TimedSample (dt, x))

-- * Stream generators

-- | Streams with Uniformly spaced samples
uniDistStream :: Arbitrary a => Gen (SignalSampleStream a)
uniDistStream = do
  x <- arbitrary
  rest <- uniDistFutureStream
  return (x, rest)

-- | Future Streams with Uniformly spaced samples
uniDistFutureStream :: Arbitrary a => Gen (FutureSampleStream a)
uniDistFutureStream = listOf arbitrarySample

-- | Streams with fixed time deltas
fixedDelayStream :: Arbitrary a => DTime -> Gen (SignalSampleStream a)
fixedDelayStream dt = do
  x <- arbitrary
  rest <- fixedDelayFutureStream dt
  return (x, rest)

-- | Future Streams with fixed time deltas
fixedDelayFutureStream :: Arbitrary a => DTime -> Gen (FutureSampleStream a)
fixedDelayFutureStream dt = listOf (arbitrarySampleAt dt)

-- | Stream with function determining sample at a specific time
fixedDelayStreamWith :: (DTime -> a) -> DTime -> Gen (SignalSampleStream a)
fixedDelayStreamWith f dt = do
  rest <- fixedDelayFutureStreamWith f dt
  return (f 0.0, rest)

-- | Future Stream with function determining sample at a specific time
fixedDelayFutureStreamWith :: (DTime -> a) -> DTime -> Gen (FutureSampleStream a)
fixedDelayFutureStreamWith f dt = listOfWith (sampleWithAt f dt)

-- * Single samples

-- | Arbitrary samples with random positive time deltas
arbitrarySample :: Arbitrary a => Gen (DTime, a)
arbitrarySample = do
  Positive dt <- arbitrary
  x <- arbitrary
  return (dt, x)

-- | Arbitrary samples with specific time delta
arbitrarySampleAt :: Arbitrary a => DTime -> Gen (DTime, a)
arbitrarySampleAt dt = do
  x <- arbitrary
  return (dt, x)

-- | Sample at a specific time, decided by aux function
sampleWithAt :: (DTime -> a) -> DTime -> Int -> Gen (DTime, a)
sampleWithAt f dt i = do
  return (dt, f (fromIntegral i * dt))

-- * Auxiliary functions

-- | Generates a list of random length. The maximum length depends on the
-- size parameter.
listOfWith :: (Int -> Gen a) -> Gen [a]
listOfWith genF = sized $ \n ->
  do k <- choose (0,n)
     vectorOfWith k genF
