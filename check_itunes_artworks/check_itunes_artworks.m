/*
 * check_itunes_artworks.m
 * check_itunes_artworks
 *
 * Created by François LAMBOLEY on 6/21/12.
 * Copyright (c) 2012 Frost Land. All rights reserved.
 */

#include <stdio.h>

#import "iTunes.h"
#import "FLErrorPrinter.h"
#import "check_itunes_artworks.h"

void OSStatusToCharStar(OSStatus status, char str[5]) {
	if (status == noErr) {
		str[0] = 'n';
		str[1] = 'o';
		str[2] = 'E';
		str[3] = 'r';
	} else {
		str[0] = (status >> 24);
		str[1] = (status >> 16) - (str[0] << 8);
		str[2] = (status >> 8)  - (str[1] << 8) - (str[0] << 16);
		str[3] = (status >> 0)  - (str[2] << 8) - (str[1] << 16) - (str[0] << 24);
	}
	
	str[4] = '\0';
}

t_error check_selected_artworks(const t_prgm_options *options) {
	@autoreleasepool {
		iTunesApplication *iTunes = [SBApplication applicationWithBundleIdentifier:@"com.apple.iTunes"];
		if (![iTunes isRunning]) {
			fprintf(stderr, "***** Error: iTunes must be running to check artworks\n");
			return ERR_ITUNES_NOT_LAUNCHED;
		}
		
		FLErrorPrinter *errorPrinter = [[FLErrorPrinter alloc] initWithFormatCString:options->output_format
																								  encoding:NSUTF8StringEncoding];
		
		for (iTunesTrack *ft in [[iTunes selection] get]) {
			@autoreleasepool {
				/* We cannot directly use the ITunesFileTrack class. If we do, we get a link error when compiling. */
				if (![ft isKindOfClass:[NSClassFromString(@"ITunesFileTrack") class]]) {
					[errorPrinter printErrorWithMessage:@"Not a File Track" track:ft];
					continue;
				}
				
				SBElementArray *artworks = [ft artworks];
				if (artworks.count == 0)
					[errorPrinter printErrorWithMessage:@"No artworks" track:ft];
				
				if (options->verbose)
					[errorPrinter printErrorWithMessage:[NSString stringWithFormat:@"Being treated. Has %d artwork(s)", artworks.count] track:ft];
				
				NSUInteger i = 0;
				for (iTunesArtwork *curArtwork in artworks) {
					++i;
					if (!options->check_all && i > 1) break;
					
					if (options->check_embed && curArtwork.downloaded)
						[errorPrinter printErrorWithMessage:[NSString stringWithFormat:@"Artwork %d is not embedded in track", i] track:ft];
					
					NSImage *curImage = [curArtwork data];
					if (options->x_size > 0 && curImage.size.width != options->x_size)
						[errorPrinter printErrorWithMessage:[NSString stringWithFormat:@"X Size of artwork %d is not correct (expected %lu, got %g)", i, options->x_size, curImage.size.width] track:ft];
					if (options->y_size > 0 && curImage.size.height != options->y_size)
						[errorPrinter printErrorWithMessage:[NSString stringWithFormat:@"Y Size of artwork %d is not correct (expected %lu, got %g)", i, options->y_size, curImage.size.height] track:ft];
					if (options->ratio >= 0 && !has_correct_ratio(curImage.size.width, curImage.size.height, options->ratio))
						[errorPrinter printErrorWithMessage:[NSString stringWithFormat:@"Ratio of artwork %d is not correct (expected %g, got %g)", i, options->ratio, curImage.size.width / curImage.size.height] track:ft];
				}
			}
		}
		
		[errorPrinter release];
	}
	
	return ERR_NO_ERR;
}
