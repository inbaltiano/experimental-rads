# load packages
library(vegan)
library(BiodiversityR)
library(plotrix)
library(graphics)
library(CCA)
library(VGAM)
library(nlme)
library(lme4)
library(languageR)
library(poilog)
library(scatterplot3d)
library(hydroGOF)

# All files should be organized as such:
# RAD: SiteID | experiment/control | year | genus | species | id2species | abundance
# Code will compare S, N and composition among treatments at each site,
# output and compare RADs, parameters for each treatment at each site.

#---------------------------------------------------------------------------------
#          setup - select wd, import data, source code,  file to collect results
#---------------------------------------------------------------------------------
#wd = "C://Users//sarah//Documents//GitHub//experimental-rads"
wd = "/Users/sarah/Documents/GitHub/experimental-rads"
setwd(wd)

source("ExpRADsFunctions.R")   #Run the code containing the functions

comms = read.csv("community_analysis_data.csv", na.strings = 'NULL')
comps = read.csv("comparison_analysis_data.csv")
names(comps)<-c('ref', 'controID','expID')
expers = read.csv("experiments_analysis_data.csv")


# output directed to expRAD_results.txt in wd. output is appended
# to existing file. output also sent to terminal. 
sink("expRAD_results.txt", append=TRUE, split=TRUE)

#--------------------------------------------------------------
#          generate values and comparisons between the sites 
#--------------------------------------------------------------
#open plotting pdf window
pdf("allRADs.pdf", 7, 10, paper = "letter", pointsize = 10)
par(mfrow=c(5,4), mar=c(1.5,2,3,1), oma=c(1,1,1,1))


#descriptive variables
refID = c()
cID = c()
eID = c()
Cshape = c()
Eshape = c()
CS = as.numeric()
CN = as.numeric()
Jc = as.numeric()
ES = as.numeric()
EN = as.numeric()
Je = as.numeric()
taxon = c()
etype = c()
# comparison variables
BCrad = as.numeric()
BCS = as.numeric()
BCN = as.numeric()
BCcomp = as.numeric()
percS = as.numeric()
percN = as.numeric()

for (iRow in 1:nrow(comps)){
  control = comps[iRow,2]  #find control in pair
  experiment = comps[iRow,3]  # find experiment in pair
  taxa = as.character(expers[which(expers[,2]==control),7])# find taxonomic group from experiments table
  type = as.character(expers[which(expers[,2]==control),4]) # find experiment type from experiments table
  ref = as.character(comps[iRow,1])
    # Check that < 10% of individuals are unidentified. If meets criteria, continue
    if (percent_unidSpp(control, comms) == "OK" & percent_unidSpp(experiment, comms) == "OK"){
      a1 = sort(as.numeric(comms[which(comms[,2] == control & comms[,7] != 0), 8])) #vector of control abundances
      a2 = sort(as.numeric(comms[which(comms[,2] == experiment & comms[,7] != 0), 8])) #vector of exp abundances
      # Check that there are at least 5 species and 30 individuals in each community, If yes, proceed.
      if (length(a1) > 4 & length(a2) > 4 & sum(a1) > 29 & sum(a2) > 29){
        # find categorical shapes (logseries vs. lognormal)
        if(expers[which(expers[,2]==control),10] == 1) { #is it raw abundance data?
         d = dist.test(a1, a2)
          Cshape = append(Cshape, d$con)
          Eshape = append(Eshape, d$exp)
          }
        else {      #if mean abundance, can't get the data, (needs integers)
          Cshape = append(Cshape, "ERROR")
          Eshape = append(Eshape, "ERROR")
          }
        #plot the compared data
        RAD_plot(control, experiment, a1, a2, taxa)
        # get summary statistics from comparisons
        BCrad = append(BCrad, BCdist(abundMerge(relabund(a1), relabund(a2))))
        BCS = append(BCS, BCdist(matrix(c(length(a1), length(a2)), nrow = 1, ncol = 2))) 
        BCN = append(BCN, BCdist(matrix(c(sum(a1),sum(a2)), nrow = 1, ncol = 2)))
        BCcomp = append(BCcomp, BCdist(subset(comms[which(comms$siteID == control | comms$siteID == experiment),])))
        percS = append(percS, ((length(a2) - length(a1))/(length(a1)))*100) 
        percN = append(percN, ((sum(a2) - sum(a1))/(sum(a1)))*100)
        taxon = append(taxon, taxa)
        etype = append(etype, type)
        # record summary descriptive variables
        refID = append(refID, ref)
        cID = append(cID, control)
        eID = append(eID, experiment)
        CS = append(CS, length(a1))
        CN = append(CN, sum(a1))
        Jc = append(Jc, round(SimpE(comms[which(comms[,2] == control),]),2))
        ES = append(ES, length(a2))
        EN = append(EN, sum(a2))
        Je = append(Je, round(SimpE(comms[which(comms[,2] == experiment),]),2))
      }}}

dev.off()


#collapse taxon types into broader categories so there aren't so many factors
taxon[taxon=='carabid']<-'insect'
taxon[taxon=='lepidopteran']<- 'insect'
taxon[taxon=='odonate']<- 'insect'
taxon[taxon=='orthoptera']<-'insect'
taxon[taxon=='orthoptera ']<-'insect'
taxon[taxon=='beetle']<-'insect'
taxon[taxon=='microarthropods']<-'microarthropod'
taxon[taxon=='reptile']<-'herpetofauna'

#--------------------------------------------------------
#          Variance partitioning analysis and results 
#--------------------------------------------------------
print ("--------------- variance partitioning results ----------------")
print ("")

#### Standardize the variables
stdz_bc_rad = standardize(BCrad)
stdz_bc_s = standardize(BCS)
stdz_bc_n = standardize(BCN)
stdz_perc_s = standardize(abs(percS))
stdz_perc_n = standardize(abs(percN))
stdz_bc_comp = standardize(BCcomp)
taxon = as.factor(taxon)
etype = as.factor(etype)

# variance partitioning of variable impact on RADs, using Bray-Curtis S and N
lm_full = lm(stdz_bc_rad ~ stdz_bc_comp + stdz_bc_s + stdz_bc_n + stdz_bc_s:stdz_bc_n)
  r2_full = summary.lm(lm_full)$r.squared
lm_comp = lm(stdz_bc_rad ~ stdz_bc_comp)
  r2_comp = summary.lm(lm_comp)$r.squared
lm_sn = lm(stdz_bc_rad ~ stdz_bc_s + stdz_bc_n + stdz_bc_s:stdz_bc_n)
  r2_sn = summary.lm(lm_sn)$r.squared

print ("using standardized bray curtis variables:")
print (paste("full model:", round(r2_full,4), "composition:", round(r2_comp,4), "state variables:", round(r2_sn,4), sep = " "))
print (paste("variance due to composition:", round(r2_full - r2_sn, 4), "variance due to state variables:", round(r2_full - r2_comp, 4), sep = " "))
print ("")

### variance partitioning of variable impact on RADs using Bray-Curtis S and N, composition and TAXONOMIC GROUP
lm_full = lm(stdz_bc_rad ~ stdz_bc_comp + stdz_bc_s + stdz_bc_n + stdz_bc_s:stdz_bc_n + taxon)
  r2_full = summary.lm(lm_full)$r.squared
lm_comm_vars = lm(stdz_bc_rad ~ stdz_bc_comp + stdz_bc_s + stdz_bc_n + stdz_bc_s:stdz_bc_n)
  r2_comm_vars = summary.lm(lm_comm_vars)$r.squared
lm_taxa = lm(stdz_bc_rad ~ taxon)
  r2_taxa = summary.lm(lm_taxa)$r.squared

print ("using standardized bray curtis variables + taxa:")
print (paste("full model:", round(r2_full,4), "community variables:", round(r2_comm_vars,4), "taxonomic group:", round(r2_taxa,4), sep = " "))
print (paste("variance due to commmunity-level vars:", round(r2_full - r2_taxa, 4), "variance due to taxa:", round(r2_full - r2_comm_vars, 4), sep = " "))
print ("")

### variance partitioning of variable impact on RADs using Bray-Curtis S and N, composition and EXPERIMENT TYPE 
lm_full = lm(stdz_bc_rad ~ stdz_bc_comp + stdz_bc_s + stdz_bc_n + stdz_bc_s:stdz_bc_n + etype)
  r2_full = summary.lm(lm_full)$r.squared
lm_comm_vars = lm(stdz_bc_rad ~ stdz_bc_comp + stdz_bc_s + stdz_bc_n + stdz_bc_s:stdz_bc_n)
  r2_comm_vars = summary.lm(lm_comm_vars)$r.squared
lm_etype = lm(stdz_bc_rad ~ etype)
  r2_etype = summary.lm(lm_etype)$r.squared

print ("using standardized bray curtis variables + experiment type:")
print (paste("full model:", round(r2_full,4), "community variables:", round(r2_comm_vars,4), "experiment type:", round(r2_etype,4), sep = " "))
print (paste("variance due to commmunity-level vars:", round(r2_full - r2_etype, 4), "variance due to experiment type:", round(r2_full - r2_comm_vars, 4), sep = " "))
print ("")

# variance partitioning of variable impact on RADs, using abs % difference S and N
lm_full = lm(stdz_bc_rad ~ stdz_bc_comp + stdz_perc_s + stdz_perc_n + stdz_perc_s:stdz_perc_n)
  r2_full = summary.lm(lm_full)$r.squared
lm_comp = lm(stdz_bc_rad ~ stdz_bc_comp)
  r2_comp = summary.lm(lm_comp)$r.squared
lm_perc_sn = lm(stdz_bc_rad ~ stdz_perc_s + stdz_perc_n + stdz_perc_n:stdz_perc_s)
  r2_perc_sn = summary.lm(lm_perc_sn)$r.squared

print ("using standardized bray curtis composition and RADs and percent difference in S and N:")
print (paste("full model:", round(r2_full,4), "composition:", round(r2_comp,4), "state variables:", round(r2_perc_sn,4), sep = " "))
print (paste("variance due to composition:", round(r2_full - r2_perc_sn, 4), "variance due to state variables:", round(r2_full - r2_comp, 4), sep = " "))
print ("")

### variance partitioning of variable impact on RADs, using abs % difference S and N, composition and TAXONOMIC GROUP
lm_full = lm(stdz_bc_rad ~ stdz_bc_comp + stdz_perc_s + stdz_perc_n + stdz_perc_s:stdz_perc_n + taxon)
  r2_full = summary.lm(lm_full)$r.squared
lm_comm_vars = lm(stdz_bc_rad ~ stdz_bc_comp + stdz_perc_s + stdz_perc_n + stdz_perc_s:stdz_perc_n)
  r2_comm_vars = summary.lm(lm_comm_vars)$r.squared
lm_taxa = lm(stdz_bc_rad ~ taxon)
  r2_taxa = summary.lm(lm_taxa)$r.squared

print ("using standardized bray curtis composition and RADs and percent difference in S and N + taxa:")
print (paste("full model:", round(r2_full,4), "community variables:", round(r2_comm_vars,4), "taxonomic group:", round(r2_taxa,4), sep = " "))
print (paste("variance due to commmunity-level vars:", round(r2_full - r2_taxa, 4), "variance due to taxa:", round(r2_full - r2_comm_vars, 4), sep = " "))
print ("")

### variance partitioning of variable impact on RADs, using abs % difference S and N, composition and EXPERIMENT TYPE 
lm_full = lm(stdz_bc_rad ~ stdz_bc_comp + stdz_perc_s + stdz_perc_n + stdz_perc_s:stdz_perc_n + etype)
  r2_full = summary.lm(lm_full)$r.squared
lm_comm_vars = lm(stdz_bc_rad ~ stdz_bc_comp + stdz_perc_s + stdz_perc_n + stdz_perc_s:stdz_perc_n)
  r2_comm_vars = summary.lm(lm_comm_vars)$r.squared
lm_etype = lm(stdz_bc_rad ~ etype)
  r2_etype = summary.lm(lm_etype)$r.squared

print ("using standardized bray curtis composition and RADs and percent difference in S and N + taxa:")
print (paste("full model:", round(r2_full,4), "community variables:", round(r2_comm_vars,4), "experiment type:", round(r2_etype,4), sep = " "))
print (paste("variance due to commmunity-level vars:", round(r2_full - r2_etype, 4), "variance due to experiment type:", round(r2_full - r2_comm_vars, 4), sep = " "))
print ("")

#---------------------------------------------------
#          Null modeling for abundance
#---------------------------------------------------
Nresult = c()
quant = as.numeric()
ControlID = as.numeric()
ExperimentID = as.numeric()

for (iRow in 1:nrow(comps)){
  control = comps[iRow,2]  #find control in pair
  experiment = comps[iRow,3]  # find experiment in pair

  # Check that < 10% of individuals are unidentified. If meets criteria, continue
  if (percent_unidSpp(control, comms) == "OK" & percent_unidSpp(experiment, comms) == "OK"){
    a1 = sort(as.numeric(comms[which(comms[,2] == control & comms[,7] != 0), 8])) #vector of control abundances
    a2 = sort(as.numeric(comms[which(comms[,2] == experiment & comms[,7] != 0), 8])) #vector of exp abundances
    
    # Check that there are at least 5 species and 30 individuals in each community, If yes, proceed.
    if (length(a1) > 4 & length(a2) > 4 & sum(a1) > 29 & sum(a2) > 29){
      
      # run null model
      data = subset(comms[which(comms$siteID == control | comms$siteID == experiment),c(2,5,6,8)])
      data$spname = paste(data$genus, data$species, sep = ".")
      data = data[,c(1,4,5)]
      #transpose data to make siteXsp matrix
      site_sp <- cast(data, siteID ~ spname, value = "abundance")
      site_sp <- as.data.frame(site_sp)
      site_sp[is.na(site_sp)] <- 0
      site_sp2 = site_sp[,-1] #take out site column for input to NullCommunities fxn
      #run null test
      result = NullCommunityN(site_sp2)
      Nresult = append(Nresult, result[[1]])
      quant = append(quant, result[[2]])
      ControlID = append(ControlID, control)
      ExperimentID = append(ExperimentID, experiment)
    }
  }
}

nullresults=cbind(Nresult, quant, ControlID, ExperimentID)

#find CN and EN which were flagged by null model
nsig = which(Nresult == "Sign.", arr.ind = T)
csigN = CN[nsig]
esigN = EN[nsig]


#---------------------------------------------------
#          Plot the data
#---------------------------------------------------

################## plot histograms of change, Fig 1 ###################################
pdf("Figure1_histograms.pdf", 2, 6, pointsize = 10)
par(mfrow=c(4,1), mar=c(3,1.5,2,0.5), oma=c(1.5,2,1,1))

binwidth <- 0.2
#Bray-Curtis dissimilarity: 0 = the same, 1 = completely different"
hist(BCcomp, xlim = c(0,1), ylim = c(0,50), breaks = seq(0, 1, by = binwidth), main = "",
     col = "gray80", xlab = "", ylab = "")
    mtext('Composition', side = 3, line = -0.75)
    mtext('Bray-Curtis dissimilarity', side = 1, line = 2, cex = 0.75)

hist(abs(percN), xlim = c(0, 700), ylim = c(0,50), breaks = seq(0, 700, by = 25), main = "",
     col = "gray80", xlab = "", ylab = "")
    mtext('Total Abundance', side = 3, line = -0.75)
    mtext('Absolute percent difference', side = 1, line = 2, cex = 0.75)

hist(abs(percS), xlim = c(0,120), ylim = c(0,40), breaks = seq(0, 120, by = 10), main = "",  
     col = "gray80",  xlab = "", ylab ="")
    mtext('Species Richness', side = 3, line = -0.75)
    mtext('Absolute percent difference', side = 1, line = 2, cex = 0.75)

hist(BCrad, xlim = c(0,1), ylim = c(0,70), breaks = seq(0, 1, by = 0.11), main = "", 
     xlab = "", ylab = "", col = "gray80")
    mtext('Rank Abundance', side = 3, line = -0.75)
    mtext('Bray-Curtis dissimilarity', side = 1, line = 2, cex = 0.75)
box("outer", lty="solid", col="black")

dev.off()

################# Figure 2. 1:1 plots of data ##########################################
pdf("Figure2_scatterplots.pdf", 2, 6, pointsize = 10)
par(mfrow=c(4,1), mar=c(1.5,1.5,2,0.5), oma=c(1.5,2,1,1))     #FIXME: SWAP AXES FOR CONTROL (Y) AND EXPERIMENTS (X) ?

# Fig 2A - plots for N
plot(NA, NA, pch = 19, log = 'xy', xlim = c(1,6500), ylim = c(1,6500),
     xlab = '', ylab = '', bty = 'n')
#x = c(0:8000, 8000:0)
#y = c(2*(0:8000), 0.5*(8000:0))
#polygon(x, y, border = NA, col = "lightpink")
#y2 = c(1.5*(0:8000), (8000:0)/1.5)
#polygon(x, y2, border = NA, col = "lightgoldenrod1")
points(CN, EN, pch = 19, col = "gray50")
#points(csigN, esigN, pch = 19, cex = 1.5, col = "black")
abline(0, 1, lty = 2, lwd = 1, col = 'black')
N_r2 = rsquare(CN, EN)
legend('topleft', paste('r2 = ', round(N_r2,3), sep = ''), bty = 'n', cex = 0.75)
mtext('Total Abundance', side = 3, line = -0.25, cex = 0.75)

# Fig 2B - plots for S
plot(NA, NA, log = 'xy', pch = 19, xlim = c(1,200), ylim = c(1,200),
     xlab = '', ylab = '', bty = 'n')
#x = c(0:300, 300:0)
#y = c(2*(0:300), 0.5*(300:0))
#polygon(x, y, border = NA, col = "lightpink")
#y2 = c(1.5*(0:300), (300:0)/1.5)
#polygon(x, y2, border = NA, col = "lightgoldenrod1")
abline(0, 1, lty = 2, lwd = 1, col = 'gray20')
points(CS, ES, pch = 19, xlim = c(5,200), ylim = c(5,200), xlab = 'c', ylab = '', main = '')
S_r2 = rsquare(CS, ES)
legend('topleft', paste('r2 = ', round(S_r2,3), sep = ''), bty = 'n', cex = 0.75)
mtext('Species Richness', side = 3, line = -0.25, cex = 0.75)

# Fig 2C - plots for evenness
plot(NA, NA, xlim = c(0,1), ylim = c(0,1), pch = 19, xlab = '', ylab = '', bty = "n")
#x = c(0:1.25, 1.25:0)
#y = c(2*(0:1.25), 0.5*(1.25:0))
#polygon(x, y, border = NA, col = "lightpink")
#y2 = c(1.5*(0:1.25), (1.25:0)/1.5)
#polygon(x, y2, border = NA, col = "lightgoldenrod1")
abline(0,1, lty = 2, lwd = 1, col = 'gray20')
points(Jc, Je, pch = 19, xlim = c(0,1), ylim = c(0,1), xlab = '', ylab = '', main = '')
J_r2 = rsquare(Jc, Je)
legend('topleft', paste('r2 = ', round(J_r2, 3), sep = ''), bty = 'n', cex = 0.75)
mtext('Evenness', side = 3, line = -0.25, cex = 0.75)

#### Fig 2D.  compare relative abundance at each rank in all paired sites
plot(NA, NA, xlim = c(0,1), ylim = c(0,1), xlab = "", ylab = "", bty = "n") 
abline(0, 1, lty = 2, col = 'gray20', lwd = 1)

c = as.numeric()
e = as.numeric()
r2 = as.numeric()

for (iRow in 1:nrow(comps)){
  control = comps[iRow,2]  #find control in pair
  experiment = comps[iRow,3]  # find experiment in pair
#  taxa = as.character(comps[iRow, 4])
#  type = as.character(comps[iRow, 7])
#  refID = as.character(comps[iRow, 1])
    #Check that < 10% of individuals are unidentified. If meets criteria, continue
    if (percent_unidSpp(control, comms) == "OK" & percent_unidSpp(experiment, comms) == "OK"){
      #Get a vector of all the abundances for each species in the control and in the experimental communities
      abun_control = sort(as.numeric(comms[which(comms[,2] == control & comms[,7] != 0), 8])) 
      abun_exprmt = sort(as.numeric(comms[which(comms[,2] == experiment & comms[,7] != 0), 8]))
      #Check that there are at least 5 species and 30 individuals in each community, If yes, proceed.
      if (length(abun_control) > 4 & length(abun_exprmt) > 4 & sum(abun_control) > 29 & sum(abun_exprmt) > 29){
        relcon = relabund(abun_control) #make the lengths the same!
        relexp = relabund(abun_exprmt)  #make the lengths the same!
        comparison_matrix = abundMerge(relcon, relexp)
        #add points to the open plot window
        points(comparison_matrix[,1], comparison_matrix[,2], pch = 19) 
        c = append(c, comparison_matrix[,1])
        e = append(e, comparison_matrix[,2])
        r2 = append(r2, rsquare(comparison_matrix[,1], comparison_matrix[,2]))
      }}}
relabun_r2 = rsquare(c, e)
relabun_rmse = rmse(e, c)
legend('topleft', paste('r2 = ', round(relabun_r2,3), sep = ''), bty = 'n', cex = 0.75)
mtext('Rank Abundance', side = 3, line = -0.25, cex = 0.75)

box("outer", lty = "solid", col = "black")
dev.off()


# histogram of R2 values
par(mfrow=c(2,1))
hist(r2[r2>0], xlim = c(0,1), ylim = c(0,75), breaks = seq(0,1, by = 0.10), col = "gray40", freq = TRUE, main = "R2 values")
h = hist(r2[r2>0], xlim = c(0,1), ylim = c(0,1), breaks = seq(0,1, by = 0.10), col = "gray40", freq = FALSE, plot = FALSE)
plot(h$mids, h$counts/114, pch = 19, xlim = c(0,1), ylim = c(0,1), type = 'l', lwd = 2, 
     bty = "n", xlab = "r2 bins", ylab = "proportion")

#-------------------------------------------------------------------
#          Print statments - descriptive info for the txt file
#-------------------------------------------------------------------
print ("--------------- summary of results ----------------")

#print ranges for values
print (paste("S ranges", min(CS,ES), "to", max(CS,ES), sep = " "))
print (paste("N ranges", min(CN,EN), "to", max(CN,EN), sep = " "))
print (paste("Bray-Curtis on composition ranges", round(min(BCcomp),4), "to", round(max(BCcomp),4), sep = " "))
print("")

#print r2 values
print (paste("S R2 = ", S_r2))
print (paste("N R2 = ", N_r2))
print (paste("relative abundances R2 = ", relabun_r2))
print (paste("J R2 = ", J_r2))
print ("")

#root mean squared error for the variables. Usually used as standard deviation of model prediction error, but can be
# used as an indicator of the degree of change between control (obs) and the experiment (sim)
n_rmse = rmse(EN, CN); print (paste("root mean squared error for N: ", round(n_rmse,4)))
s_rmse = rmse(ES, CS); print (paste("root mean squared error for S: ", round(s_rmse,4)))
print (paste("root mean squared error for relative abundances at each rank: ", round(relabun_rmse,4)))
j_rmse = rmse(Je, Jc); print (paste("root mean squared error for J: ", round(j_rmse,4)))
print ("")

#count the communities displaying various shapes. This Does take into account duplicates. Should be correct
print ("The number of communities for logseries vs. lognormal RADs:")
count_RAD_shapes(cID, eID, Cshape, Eshape)

#close sink file
sink()
