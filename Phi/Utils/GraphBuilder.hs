{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE RecordWildCards            #-}
module Phi.Utils.GraphBuilder where

import           Control.Monad.State
import           Data.Graph.Inductive.Graph (DynGraph, Graph)
import qualified Data.Graph.Inductive.Graph as Graph

data GraphBuilderState gr a b = GraphBuilderState
  { graphBuilderRoot     :: Maybe Graph.Node
  , graphBuilderVoidNode :: Graph.Node
  , graphBuilderGraph    :: gr a b
  }

newtype GraphBuilder gr a b x = GraphBuilder {
    runGraphBuilder :: State (GraphBuilderState gr a b) x
  } deriving (Functor, Applicative, Monad, MonadState (GraphBuilderState gr a b))

voidNodeGraphBuilderState :: DynGraph gr => a -> GraphBuilderState gr a b
voidNodeGraphBuilderState voidLabel
  = flip execState emptyGraphBuilderState . runGraphBuilder $ do
    node <- freshNode voidLabel
    modify (\s -> s { graphBuilderVoidNode = node })

emptyGraphBuilderState :: Graph gr => GraphBuilderState gr a b
emptyGraphBuilderState = GraphBuilderState
  { graphBuilderRoot = Nothing
  , graphBuilderVoidNode = error "void node is not defined"
  , graphBuilderGraph = Graph.empty
  }

freshNode :: DynGraph gr => a -> GraphBuilder gr a b Graph.Node
freshNode label = do
  nodes <- Graph.newNodes 1 <$> gets graphBuilderGraph
  let node = head nodes
  modify $ \s@GraphBuilderState{..} ->
    s { graphBuilderGraph = Graph.insNode (node, label) graphBuilderGraph }
  return node

edgeFromTo :: DynGraph gr => Graph.Node -> b -> Graph.Node -> GraphBuilder gr a b ()
edgeFromTo from label to = do
  modify $ \s@GraphBuilderState{..} ->
    s { graphBuilderGraph = Graph.insEdge (from, to, label) graphBuilderGraph }

voidNode :: GraphBuilder gr a b Graph.Node
voidNode = gets graphBuilderVoidNode

setRoot :: Graph.Node -> GraphBuilder gr a b ()
setRoot node = do
  modify (\s -> s { graphBuilderRoot = Just node })

buildGraph :: DynGraph gr => a -> GraphBuilder gr a b x -> (x, gr a b)
buildGraph voidLabel
  = fmap graphBuilderGraph
  . flip runState (voidNodeGraphBuilderState voidLabel)
  . runGraphBuilder

buildGraph_ :: DynGraph gr => a -> GraphBuilder gr a b x -> gr a b
buildGraph_ voidLabel = snd . buildGraph voidLabel