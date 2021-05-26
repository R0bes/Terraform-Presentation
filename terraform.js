/*
 * highlight.js terraform syntax highlighting definition
 *
 * @see https://github.com/highlightjs/highlight.js
 *
 * :TODO:
 *
 * @package: highlightjs-terraform
 * @author:  Nikos Tsirmirakis <nikos.tsirmirakis@winopsdba.com>
 * @since:   2019-03-20
 *
 * Description: Terraform (HCL) language definition
 * Category: scripting
 */



function defineTF(hljs) {

	
	var NUMBERS = {
		className: 'number',
		begin: '[0-9]+',
		relevance: 0
	}

	var STRINGS = {
		className: 'string',
		begin: '"',
		end: '"',
		contains: [{
			className: 'variable',
			begin: '\\${',
			end: '\\}',
			relevance: 9,
			contains: [{
				className: 'string',
				begin: '"',
				end: '"'
			}, {
			className: 'meta',
			begin: '[A-Za-z_0-9]*' + '\\(',
			end: '\\)',
			contains: [
				NUMBERS, 
				{
					className: 'string',
					begin: '"',
					end: '"',
					contains: [{
						className: 'variable',
						begin: '\\${',
						end: '\\}',
						contains: [{
							className: 'string',
							begin: '"',
							end: '"',
							contains: [{
								className: 'variable',
								begin: '\\${',
								end: '\\}'
							}]
						}, {
							className: 'meta',
							begin: '[A-Za-z_0-9]*' + '\\(',
							end: '\\)'
						}]
					}]
          		},
          	'self']
			}]
		}]
	};

	return {
		case_insensitive: false,
	  	aliases: ['terraform'],
	  	keywords: 'resource variable provider output locals module data terraform provisioner|10',
	  	literal: 'false true null when interpreter command',
		built_in: ['map', 'list'],
	  	contains: [
			hljs.COMMENT('\\#', '$'),
			NUMBERS,
		  	STRINGS
	  	]
	}
}

var module = module ? module : {};

module.exports = function(hljs) {
    hljs.registerLanguage('terraform', defineTF);
};
module.exports.definer = defineTF;





	/*

	var STRINGS = {
		className: 'string',
		begin: '"',
		end: '"',
		contains: [{
			className: 'variable',
			begin: '\\${',
			end: '\\}',
			relevance: 9,
			contains: [{
				className: 'string',
				begin: '"',
				end: '"'
			}, {
			className: 'meta',
			begin: '[A-Za-z_0-9]*' + '\\(',
			end: '\\)',
			contains: [
				NUMBERS, 
				{
					className: 'string',
					begin: '"',
					end: '"',
					contains: [{
						className: 'variable',
						begin: '\\${',
						end: '\\}',
						contains: [{
							className: 'string',
							begin: '"',
							end: '"',
							contains: [{
								className: 'variable',
								begin: '\\${',
								end: '\\}'
							}]
						}, {
							className: 'meta',
							begin: '[A-Za-z_0-9]*' + '\\(',
							end: '\\)'
						}]
					}]
          		},
          	'self']
			}]
		}]
	};



	return {
	  	case_insensitive: false,
		aliases: ['terraform'],
		keywords: ['resource', 'variable', 'provider', 'output', 'locals', 'module', 'data', 'terraform', 'provisioner'],
		literal: ['false', 'true', 'null', 'when', 'interpreter', 'command'],
		contains: [
	   		hljs.COMMENT('\\#', '$'),
	   		NUMBERS,
			STRINGS
		]
	}
}
*/
