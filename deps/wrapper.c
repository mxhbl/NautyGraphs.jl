#include <nauty.h>

void densenauty_wrap(graph *g, int *lab, int *ptn, int *orbits, optionblk *options, statsblk *stats, int m, int n, graph *canong)
{
	options->dispatch = &dispatch_graph;
	densenauty(g, lab, ptn, orbits, options, stats, m, n, canong);
	return;
}


int wordsize()
{
	return WORDSIZE;
}
