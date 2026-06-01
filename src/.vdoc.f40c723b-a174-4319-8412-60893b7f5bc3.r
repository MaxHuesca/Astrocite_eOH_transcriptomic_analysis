plot_volcano <- function(
  res_labes,
  LFC = 2,
  FDR = 1e-10,
  plot_name = "Volcano plot"
) {
  #Asegurar que es un data frame el input
  res_df <- as.data.frame(res_labes)

  # Asignar los limites para el ploteo
  volcano_LFC_limit = 12
  volcano_FDR_limit = 70

  # Colores de las condiciones
  vpcolors = c("gray", "blue", "red")
  names(vpcolors) = c("NO", "DOWN", "UP")

  # Hacer el volcano plot
  volcano_p <- ggplot(
    data = res_df,
    aes(
      x = log2FoldChange,
      y = -log10(padj),
      col = DE
    )
  ) +
    geom_point() +
    labs(
      title = plot_name,
      x = "log2 Expression fold change",
      y = "-log10 FDR"
    ) +
    coord_cartesian(
      xlim = c(-volcano_LFC_limit, volcano_LFC_limit),
      ylim = c(0, volcano_FDR_limit)
    ) +
    scale_color_manual(values = vpcolors) +
    geom_vline(
      xintercept = c(-LFC, LFC),
      col = "black",
      linetype = "longdash"
    ) +
    geom_hline(
      yintercept = -log10(FDR),
      col = "black",
      linetype = "longdash"
    ) +
    theme_classic(base_size = 15, base_line_size = 1)

  return(volcano_p)
}
