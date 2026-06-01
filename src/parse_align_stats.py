import pandas as pd
import argparse as ap
import os
import seaborn as sns
import matplotlib.pyplot as plt



def plot_stats(res_df:pd.DataFrame) : 
    """
    Function that makes the analysis plots 
    Args: 
        res_df : data frame with the results of the alignment
    Returns: 
        none
    """
    # ========================================================================
    # Total aligned vs time
    # ======================================================================== 
    res_df = res_df.dropna()
    
    label_colors = {"hisat": "#161fcfff", "star": "#d11313ff"}

    aligned_time, ax = plt.subplots(figsize=(10, 6))
    aligned_time.set_facecolor("#d7ecfff1")
    sns.scatterplot(
        data=res_df,
        x="Total_aligned",
        y="Time(min)",
        hue="aligner",
        palette=label_colors,
        style="Type",
        ax=ax,
    )
    ax.set_title("Total aligned vs time")
    ax.legend(loc="upper left", bbox_to_anchor=(1.02, 1))
    ax.grid(True, linestyle="--", alpha=0.5)
    ax.set_facecolor("#7a6ab949") 
    
    #save the plot 
    aligned_time.savefig(
    "aligned_vs_time.png",
    dpi=300,
    bbox_inches="tight"
    )
    plt.close()
    # ========================================================================
    # Multi mapped vs no aligned
    # ========================================================================
    multi_non, ax = plt.subplots(figsize=(10, 6))
    multi_non.set_facecolor("#d7ecfff1")
    sns.scatterplot(
        data=res_df,
        x="Multimaped",
        y="Non_aligned",
        hue="aligner",
        palette=label_colors,
        style="Type",
        ax=ax,
    )
    ax.set_title("Multi mapped vs no aligned")
    ax.legend(loc="upper left", bbox_to_anchor=(1.02, 1))
    ax.grid(True, linestyle="--", alpha=0.5)
    ax.set_facecolor("#7a6ab949") 
    
    #save the plot 
    multi_non.savefig(
    "Multi_mapped_vs_no_aligned.png",
    dpi=300,
    bbox_inches="tight"
    )
    plt.close()
    

def parse_hisat(dict_res:dict, flag:str) -> pd.DataFrame:
    """
    Fuction that parse the hisat log files and the met tables
    Args:
        -dict_res: a dictionary with the results of the hisat log file
        -met_path: the path to the hisat met file
        -flag: a string that indicate if the log file is for paired or unpaired reads
    Returns:     
        -dataframe with the parsed results
    
    """
    hi_dict ={}
    # extract the overall aligned
    hi_dict["Total_aligned"]=float(dict_res["Overall alignment rate"].split("%")[0].strip()) / 100
    match flag:
        case "PR":
            # extract all the sequences:
            all_seqs = int(dict_res["Total pairs"]) + int(
                    dict_res["Total unpaired reads"]
                )
            # now we store sequences that were not aligned
            hi_dict["Non_aligned"]=(
                    int(dict_res["Aligned concordantly or discordantly 0 time"].split(" ")[1])
                    + int(dict_res["Aligned 0 time"].split(" ")[1])
                )/ all_seqs
            # now extract the reads unique aligned
            hi_dict["Unique_aligned"]=(
                    int(dict_res["Aligned concordantly 1 time"].split(" ")[1])
                    + int(dict_res["Aligned 1 time"].split(" ")[1])
                )/ all_seqs
            # The reads multimaped
            hi_dict["Multimaped"]=(
                    int(dict_res["Aligned discordantly 1 time"].split(" ")[1])
                    + int(dict_res["Aligned >1 times"].split(" ")[1])
                )/ all_seqs
            # finally the time it taked
            hi_dict["Time(min)"]=float(dict_res["time_align"])/60
        case "UN":
            # extract all the sequences:
            all_seqs = int(dict_res["Total reads"])
            # if it can parsed like the above structure it may be a un parired aligenment
            hi_dict["Non_aligned"]=(int(dict_res["Aligned 0 time"].split(" ")[1])) / all_seqs
            # now extract the reads unique aligned
            hi_dict["Unique_aligned"]=(int(dict_res["Aligned 1 time"].split(" ")[1])) / all_seqs
            # The reads multimaped
            hi_dict["Multimaped"]=(int(dict_res["Aligned >1 times"].split(" ")[1])) / all_seqs
            # finally the time it taked
            hi_dict["Time(min)"]=float(dict_res["time_align"])/60
    #add the total of seqs
    hi_dict["Total_reads"]= all_seqs
    # finally we add the result to the hisat_df
    return pd.DataFrame.from_dict([hi_dict])


def parse_star(dict_res:dict) -> pd.DataFrame:
    """
    Function that parse the star log files 
    Args:
        -dict_res: a dictionary with the results of the star log file
    Returns:     
        -dataframe with the parsed results
    """
    str_dict = {} 
    # extract all the sequences:
    all_seqs = int(dict_res["Number of input reads "])
    # extract the overall aligned
    str_dict["Total_aligned"]=(
            int(dict_res["Uniquely mapped reads number "])
            + int(dict_res["Number of reads mapped to multiple loci "])
            + int(dict_res["Number of reads mapped to too many loci "])
        )/ all_seqs

    # now we store sequences that were not aligned
    str_dict["Non_aligned"]=(
                int(dict_res["Number of reads unmapped: too short "])
                + int(dict_res["Number of reads unmapped: too many mismatches "])
                + int(dict_res["Number of reads unmapped: other "])
            )/ all_seqs
    # now extract the reads unique aligned
    str_dict["Unique_aligned"]=int(dict_res["Uniquely mapped reads number "]) / all_seqs

    # The reads multimaped
    str_dict["Multimaped"]=(
                int(dict_res["Number of reads mapped to multiple loci "])
                + int(dict_res["Number of reads mapped to too many loci "])
        )/ all_seqs
    
    # finally the time it taked
    day_s= int(dict_res["Started mapping on "].split(" ")[1])
    day_f= int(dict_res["Finished on "].split(" ")[1])
    start_list = dict_res["Started mapping on "].split(" ")[2].split(":")
    finish_list = dict_res["Finished on "].split(" ")[2].split(":")
    start_time = (
        int(start_list[0]) * 3600 + int(start_list[1]) * 60 + int(start_list[2])
    )
    finish_time = (
        int(finish_list[0]) * 3600 + int(finish_list[1]) * 60 + int(finish_list[2])
    )
    if day_f > day_s: 
        finish_time+=3600*24*(day_f -day_s)
    
    time_s = (finish_time - start_time)/60
    
    str_dict["Time(min)"]=time_s
    #add the total of seqs 
    str_dict["Total_reads"]=all_seqs
    # finally we add the result to the star_df
    return pd.DataFrame.from_dict([str_dict])



def parser(): 
    """
    function that parse the arguments for the script
     -p or --paths: the path to the folder where the alignment results are stored
     Returns:
        -the arguments parsed
    """
    parser = ap.ArgumentParser(description="Parse the alignment results")
    parser.add_argument(
        "-p",
        "--paths",
        type=str,
        help="A list splited by a coma of the paths with the reports from the aligment",
        required=True,
    )
    return parser.parse_args()



def main():
    # get the arguments
    args = parser()
    path = args.paths
    path_list=path.split(",")

    #dataframes
    columns=["SRR_id","Total_aligned", "Non_aligned", "Unique_aligned", "Multimaped", "Time(min)", "Total_reads", "Type", "aligner"]
    parsed_df = pd.DataFrame(pd.DataFrame(columns=columns))

    for align_stat in path_list:
        #create the path and obtain the file name
        temp_pth=os.path.join(align_stat)
        file_name=align_stat.split("/")[-1].split("_")
        #obatin the features from the stat file 
        aligner=file_name[0]
        type_read=file_name[1]
        sample=file_name[2]
        try:  
            with open(temp_pth, "r") as read_f:
                raw_file=read_f.read().split("\n")
        except Exception as e:
            print(f"Error parsing {align_stat}: {e}")
            parsed_df=pd.concat([parsed_df, pd.DataFrame(columns=columns, data=[[sample]+[None]*8])])
            continue

        #parsed in order of the aligner 
        if aligner == "hisat":
            dict_res = dict([line.strip().split(":") for line in raw_file if ":" in line])
            temp_df = parse_hisat(dict_res, type_read)
            temp_df["aligner"]=["hisat"]
        else:
            temp_list = [line.strip().split("|") for line in raw_file if "|" in line]
            # clean the list
            dict_res = dict([[lis[0], lis[1].strip()] for lis in temp_list if len(lis) == 2])  
            temp_df = parse_star(dict_res)
            temp_df["aligner"]=["star"]

        #add the identfier columns 
        temp_df["Type"]=[type_read]
        temp_df["SRR_id"]=[sample]
        # add the temp_df to the parsed_df
        parsed_df=pd.concat([parsed_df,temp_df])

   
    
    # save the dataframe
    parsed_df.to_csv("alignment_stats.csv", index=False)
    #make the plots 
    plot_stats(parsed_df)

if __name__ == "__main__":
    main()