{-# LANGUAGE GADTs  #-}
-- TODO

-- Important question: because this FRP implement uses CPS,
-- it is stateful, and sampling twice in one time period
-- is not necessarily the same as sampling once. This means that
-- tauApp, or next, might not work correctly. It's important to
-- see what is going on there... :(

module FRP.Yampa.LTLFuture where

------------------------------------------------------------------------------
import FRP.Yampa
import FRP.Yampa.Stream

-- * Temporal Logics based on SFs

-- | Type representing future-time linear temporal logic with until and next.
data TPred a where
  Prop       :: SF a Bool -> TPred a
  And        :: TPred a -> TPred a -> TPred a
  Or         :: TPred a -> TPred a -> TPred a
  Not        :: TPred a -> TPred a
  Implies    :: TPred a -> TPred a -> TPred a
  Always     :: TPred a -> TPred a
  Eventually :: TPred a -> TPred a
  Next       :: TPred a -> TPred a
  Until      :: TPred a -> TPred a -> TPred a

-- | Apply a transformation to the leaves (to the SFs)
tPredMap :: (SF a Bool -> SF a Bool) -> TPred a -> TPred a
tPredMap f (Prop sf)       = Prop (f sf)
tPredMap f (And t1 t2)     = And (tPredMap f t1) (tPredMap f t2)
tPredMap f (Or t1 t2)      = Or (tPredMap f t1) (tPredMap f t2)
tPredMap f (Not t1)        = Not (tPredMap f t1)
tPredMap f (Implies t1 t2) = Implies (tPredMap f t1) (tPredMap f t2)
tPredMap f (Always t1)     = Always (tPredMap f t1)
tPredMap f (Eventually t1) = Eventually (tPredMap f t1)
tPredMap f (Next t1)       = Next (tPredMap f t1)
tPredMap f (Until t1 t2)   = Until (tPredMap f t1) (tPredMap f t2)

-- * Temporal Evaluation

-- | Evaluates a temporal predicate at time T=0 against a sample stream.
--
-- Returns 'True' if the temporal proposition is currently true.
evalT :: TPred a -> SignalSampleStream a -> Bool
evalT (Prop sf)       = \stream -> firstSample $ fst $ evalSF sf stream
evalT (And t1 t2)     = \stream -> evalT t1 stream && evalT t2 stream
evalT (Or  t1 t2)     = \stream -> evalT t1 stream || evalT t2 stream
evalT (Implies t1 t2) = \stream -> not (evalT t1 stream) || evalT t2 stream
evalT (Always  t1)    = \stream -> evalT t1 stream && evalT (Next (Always t1)) stream
evalT (Eventually t1) = \stream -> evalT t1 stream || evalT (Next (Eventually t1)) stream
evalT (Until t1 t2)   = \stream -> (evalT t1 stream && evalT (Next (Until t1 t2)) stream)
                                   || evalT t2 stream
evalT (Next t1)       = \stream -> case stream of
                                    (a,[]) -> True   -- This is important. It determines how
                                                     -- eventually, always and next behave at the
                                                     -- end of the stream, which affects that is and isn't
                                                     -- a tautology. It should be reviewed very carefully.
                                    (a1,(dt, a2):as) -> evalT (tauApp t1 a1 dt) (a2, as)
  where
    -- Tau-application (transportation to the future)
    tauApp :: TPred a -> a -> DTime -> TPred a
    tauApp pred sample dtime = tPredMap (\sf -> snd (evalFuture sf sample dtime)) pred