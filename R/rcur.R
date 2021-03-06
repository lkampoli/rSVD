#' @title  Randomized CUR matrix decomposition.
#
#' @description Randomized CUR matrix decomposition.
#
#' @details
#' Algorithm for computing the CUR matrix decomposition of a rectangular \eqn{(m, n)} matrix \eqn{A}, 
#' with target rank \eqn{k << min(m,n)}. The input matrix is factored as 
#' 
#' \deqn{A = C * U * R} 
#' 
#' using the \code{\link{rid}} decomposition. The factor matrix \eqn{C} is formed using actual 
#' columns of \eqn{A}, also called the partial column skeleton. The factor matrix \eqn{R} is formed 
#' using actual rows of \eqn{A}, also called the partial row skeleton.
#' 
#' If \eqn{rand=TRUE} a probabilistic strategy is used to compute the decomposition, otherwise a
#' deterministic algorithm is used. 
#'
#'
#' @param A   array_like; \cr
#'            numeric \eqn{(m, n)} input matrix (or data frame). \cr
#'            If the data contain \eqn{NA}s na.omit is applied.
#'            
#' @param k   integer; \cr
#'            target rank of the low-rank approximation, i.e., the number of columns/rows
#'            to be selected. It is required that \eqn{k} is smaller or equal to \eqn{min(m,n)}.
#'        
#' @param p   integer, optional; \cr
#'            oversampling parameter (default \eqn{p=10}).
#'
#' @param q   integer, optional; \cr
#'            number of additional power iterations (default \eqn{q=0}).
#'
#' @param idx_only  bool, optional; \cr
#'              if (\eqn{TRUE}), only the index set \code{C.idx} and \code{R.idx} is returned, but not 
#'              the matrices \code{C} and \code{R}. 
#'              This is more memory efficient, when dealing with large-scale data. 
#'              
#' @param rand  bool, optional; \cr
#'              if (\eqn{TRUE}), a probabilistic strategy is used, otherwise a deterministic algorithm is used.                
#'
#'
#' @return \code{rcur} returns a list with class \eqn{id} containing the following components:
#'\describe{
#'    \item{C}{ array_like; \cr
#'              column subset \eqn{C = A[,C.idx]}; \eqn{(m, k)} dimensional array.
#'    }
#'
#'    \item{R}{ Array_like. \cr
#'               row subset \eqn{R = A[R.idx, ]}; \eqn{(k, n)} dimensional array.
#'    }
#'    
#'    \item{U}{ array_like; \cr
#'             connector matrix; \eqn{(k,k)} dimensional array.
#'    }
#'    
#'    \item{C.idx}{ array_like; \cr
#'                index set of the \eqn{k} selected columns used to form \eqn{C}. 
#'    }   
#' 
#'    \item{R.idx}{ array_like; \cr
#'                index set of the \eqn{k} selected rows used to form \eqn{R}. 
#'    }   
#'       
#'      
#'    \item{C.scores}{ array_like; \cr
#'                   scores of the selected columns.
#'    } 
#' 
#'    \item{R.scores}{ array_like; \cr
#'                   scores  of the selected rows.
#'    }                   
#'}                                                       
#'
#' @references
#' \itemize{
#'  \item [1] N. B. Erichson, S. Voronin, S. L. Brunton and J. N. Kutz. 2019.
#'        Randomized Matrix Decompositions Using {R}. 
#'        Journal of Statistical Software, 89(11), 1-48.
#'        \url{http://doi.org/10.18637/jss.v089.i11}.
#' 
#'   \item  [2] N. Halko, P. Martinsson, and J. Tropp.
#'          "Finding structure with randomness: probabilistic
#'          algorithms for constructing approximate matrix
#'          decompositions" (2009).
#'          (available at arXiv \url{http://arxiv.org/abs/0909.4061}).
#'}
#'
#'
#' @author N. Benjamin Erichson, \email{erichson@berkeley.edu}
#'
#' @seealso \code{\link{rid}}
#'
#'
#'
#' @examples
#' \dontrun{
#' # Load test image
#' data('tiger')
#'
#' # Compute (column) randomized interpolative decompsition
#' # Note that the image needs to be transposed for correct plotting
#' out <- rcur(tiger, k = 150)
#'
#' # Reconstruct image
#' tiger.re <- out$C %*% out$U %*% out$R
#'
#' # Compute relative error
#' print(norm(tiger-tiger.re, 'F') / norm(tiger, 'F')) 
#'
#' # Plot approximated image
#' image(tiger.re, col = gray((0:255)/255))
#' }

#' @export
rcur <- function(A, k = NULL, p = 10, q = 0, idx_only = FALSE, rand = TRUE) UseMethod("rcur")

#' @export
rcur.default <- function(A, k = NULL, p = 10, q = 0, idx_only = FALSE, rand = TRUE) {

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Checks
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  if (any(is.na(A))) {
    warning("Missing values are omitted: na.omit(A).")
    A <- stats::na.omit(A)
  }     

  m <- nrow(A)
  n <- ncol(A)  
  
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Init id object
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  rcurObj = list( C = NULL,
                R = NULL,
                U = NULL,
                C.idx = NULL,
                R.idx = NULL,
                C.scores = NULL,
                R.scores = NULL,
                rand = rand)  
  

  
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Set target rank
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  if(is.null(k)) k <- min(n,m)
  if(k > min(m,n)) k <- min(m,n)
  if(k < 1) stop("Target rank is not valid!")
  
  
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  #Compute column ID
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ 
  out_cid <- rid(A, k = k, p = p, q = q, mode = 'column', idx_only = TRUE, rand = rand)
  
  # Select column subset
  if(idx_only == FALSE) {
    rcurObj$C <- matrix(A[, out_cid$idx], nrow = m, ncol = k)    
    colnames(rcurObj$C) <- colnames(A)[out_cid$idx]
    rownames(rcurObj$C) <- rownames(A)
  } 
  
  rcurObj$C.idx <- out_cid$idx
  rcurObj$C.scores <- out_cid$scores

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  #Compute row ID of C
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  #out_rid <- rid(A[, rcurObj$C.idx], k = k, p = p, q = q, mode = 'row', idx_only = TRUE, rand = FALSE)
  out <- qr(H(A[, rcurObj$C.idx]), LAPACK=TRUE) 
  
  # Get index set
  rcurObj$R.idx <- out$pivot[1:k] # Get row set

  # Get R =: S
  S <- qr.R( out ) 
  #Q <- qr.Q( out ) 
  
  # Select row subset
  if(idx_only == FALSE) {
    rcurObj$R <- matrix(A[rcurObj$R.idx,], nrow = k, ncol = n) 
    rownames(rcurObj$R) <- rownames(A)[rcurObj$R.idx]
    colnames(rcurObj$R) <- colnames(A)
  } 
  
  rcurObj$R.scores <- abs(diag(S))[1:k]

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  #Compute U
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  #rcurObj$U = Z %*% MASS::ginv(matrix(A[rcurObj$R.idx, ], nrow = k, ncol = n) )    
  rcurObj$U = out_cid$Z %*% pinv(matrix(A[rcurObj$R.idx, ], nrow = k, ncol = n))

  #colinv = matrix(0, 1 , n)
  #colinv[out_cid$pivot] = 1:n
  
  #V = rbind(diag(k), H(out_cid$Z))[colinv,]
  
  # Rt*Ut = V via RRt*Ut = R*V
  #RV = rcurObj$R %*% V
  #rcurObj$U = H(pinv(rcurObj$R %*% H(rcurObj$R)) %*% RV)

  # Rt*Ut = V
  #rcurObj$U = H(pinv(H(rcurObj$R)) %*% V)

  
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Return
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  class(rcurObj) <- "rcur"
  return( rcurObj )
}  



