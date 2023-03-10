library(tidyverse)
library(igraph)

edgelist <- data.frame(
  from = c(1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 5, 5, 6, 6, 7, 8),
  to = c(2, 3, 4, 5, 6, 4, 5, 6, 7, 8, 7, 8, 7, 8, 9, 9),
  capacity = c(20, 30, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99),
 # cost = c(0, 0, 1, 2, 3, 4, 3, 2, 3, 2, 3, 4, 5, 6, 0, 0)
  cost = c(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))

g <- graph_from_edgelist(as.matrix(edgelist[,c('from','to')]))

E(g)$capacity <- edgelist$capacity
E(g)$cost <- edgelist$cost

plot(g, edge.label = E(g)$capacity)
plot(g, edge.label = E(g)$cost)


#solution

library(magrittr)

# Add edge ID
edgelist$ID <- seq(1, nrow(edgelist))

glimpse(edgelist)
?glimpse


createConstraintsMatrix <- function(edges, total_flow) {
  
  # Edge IDs to be used as names
  names_edges <- edges$ID
  # Number of edges
  numberof_edges <- length(names_edges)
  
  # Node IDs to be used as names
  names_nodes <- c(edges$from, edges$to) %>% unique
  # Number of nodes
  numberof_nodes <- length(names_nodes)
  
  # Build constraints matrix
  constraints <- list(
    lhs = NA,
    dir = NA,
    rhs = NA)
  
  #' Build capacity constraints ------------------------------------------------
  #' Flow through each edge should not be larger than capacity.
  #' We create one constraint for each edge. All coefficients zero
  #' except the ones of the edge in question as one, with a constraint
  #' that the result is smaller than or equal to capacity of that edge.
  
  # Flow through individual edges
  constraints$lhs <- edges$ID %>%
    length %>%
    diag %>%
    set_colnames(edges$ID) %>%
    set_rownames(edges$ID)
  # should be smaller than or equal to
  constraints$dir <- rep('<=', times = nrow(edges))
  # than capacity
  constraints$rhs <- edges$capacity
  
  
  #' Build node flow constraints -----------------------------------------------
  #' For each node, find all edges that go to that node
  #' and all edges that go from that node. The sum of all inputs
  #' and all outputs should be zero. So we set inbound edge coefficients as 1
  #' and outbound coefficients as -1. In any viable solution the result should
  #' be equal to zero.
  
  nodeflow <- matrix(0,
                     nrow = numberof_nodes,
                     ncol = numberof_edges,
                     dimnames = list(names_nodes, names_edges))
  
  for (i in names_nodes) {
    
    # input arcs
    edges_in <- edges %>%
      filter(to == i) %>%
      select(ID) %>%
      unlist
    # output arcs
    edges_out <- edges %>%
      filter(from == i) %>%
      select(ID) %>%
      unlist
    
    # set input coefficients to 1
    nodeflow[
      rownames(nodeflow) == i,
      colnames(nodeflow) %in% edges_in] <- 1
    
    # set output coefficients to -1
    nodeflow[
      rownames(nodeflow) == i,
      colnames(nodeflow) %in% edges_out] <- -1
  }
  
  # But exclude source and target edges
  # as the zero-sum flow constraint does not apply to these!
  # Source node is assumed to be the one with the minimum ID number
  # Sink node is assumed to be the one with the maximum ID number
  sourcenode_id <- min(edges$from)
  targetnode_id <- max(edges$to)
  # Keep node flow values for separate step below
  nodeflow_source <- nodeflow[rownames(nodeflow) == sourcenode_id,]
  nodeflow_target <- nodeflow[rownames(nodeflow) == targetnode_id,]
  # Exclude them from node flow here
  nodeflow <- nodeflow[!rownames(nodeflow) %in% c(sourcenode_id, targetnode_id),]
  
  # Add nodeflow to the constraints list
  constraints$lhs <- rbind(constraints$lhs, nodeflow)
  constraints$dir <- c(constraints$dir, rep('==', times = nrow(nodeflow)))
  constraints$rhs <- c(constraints$rhs, rep(0, times = nrow(nodeflow)))
  
  
  #' Build initialisation constraints ------------------------------------------
  #' For the source and the target node, we want all outbound nodes and
  #' all inbound nodes to be equal to the sum of flow through the network
  #' respectively
  
  # Add initialisation to the constraints list
  constraints$lhs <- rbind(constraints$lhs,
                           source = nodeflow_source,
                           target = nodeflow_target)
  constraints$dir <- c(constraints$dir, rep('==', times = 2))
  # Flow should be negative for source, and positive for target
  constraints$rhs <- c(constraints$rhs, total_flow * -1, total_flow)
  
  return(constraints)
}

constraintsMatrix <- createConstraintsMatrix(edgelist, 30)

library(lpSolve)

# Run lpSolve to find best solution
solution <- lp(
  direction = 'min',
  objective.in = edgelist$cost,
  const.mat = constraintsMatrix$lhs,
  const.dir = constraintsMatrix$dir,
  const.rhs = constraintsMatrix$rhs,
  compute.sens = 1,
  )

# Print vector of flow by edge
solution$solution
solution$sens.coef.to
solution$sens.coef.from
# Include solution in edge dataframe
edgelist$flow <- solution$solution



library(igraph)

g <- edgelist %>%
  # igraph needs "from" and "to" fields in the first two colums
  select(from, to, ID, capacity, cost, flow) %>%
  # Make into graph object
  graph_from_data_frame()

# Get some colours in to visualise cost
E(g)$color[E(g)$cost == 0] <- 'royalblue'
E(g)$color[E(g)$cost == 1] <- 'yellowgreen'
E(g)$color[E(g)$cost == 2] <- 'gold'
E(g)$color[E(g)$cost >= 3] <- 'firebrick'


#add edge only if observed
#dashed line if no flow
E(g)$lty<-as.numeric((E(g)$flow)<1)+1

# Flow as edge size,
# cost as colour
plot(g, edge.width = (E(g)$flow+1),
     edge.arrow.size=((E(g)$flow/50)),
     curved=T)

#

as.numeric((E(g)$flow)>1)
 



