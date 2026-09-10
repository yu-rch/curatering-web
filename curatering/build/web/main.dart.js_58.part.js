((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,C,G,E,D={aLf:function aLf(){}},B,F
J=c[1]
A=c[0]
C=c[2]
G=c[76]
E=c[70]
D=a.updateHolder(c[14],D)
B=c[77]
F=c[64]
D.aLf.prototype={
Ez(d){return this.ayU(d)},
ayU(d){var x=0,w=A.l(y.i),v,u,t,s,r,q
var $async$Ez=A.m(function(e,f){if(e===1)return A.i(f,w)
for(;;)switch(x){case 0:x=3
return A.d(A.eH(A.bF("https://curatering.up.railway.app/api/online-inquiries",0,null),C.a4.cr(d,null),null,F.mb).cM(G.fh),$async$Ez)
case 3:q=f
if(q.b<200||q.b>=300){u="Failed to submit online inquiry ("+q.b+")"
try{s=q
t=C.a4.bu(A.cG(A.cF(s.e)).ba(s.w),null)
if(y.l.b(t)&&t.h(0,"message")!=null)u=J.w(t.h(0,"message"))}catch(p){}throw A.p(A.ar4(u,q.b))}s=q
if(C.e.m(A.cG(A.cF(s.e)).ba(s.w)).length===0){v=C.iz
x=1
break}s=q
t=C.a4.bu(A.cG(A.cF(s.e)).ba(s.w),null)
v=y.l.b(t)?A.aD(t,y.g,y.b):C.iz
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$Ez,w)},
a5_(d,e,f){return this.bku(d,e,f)},
bku(d,e,f){var x=0,w=A.l(y.i),v
var $async$a5_=A.m(function(g,h){if(g===1)return A.i(h,w)
for(;;)switch(x){case 0:v=$.bO().ea("/api/public/events/theme-design/yolo-sam-infer",A.Q(["imageBase64",d,"confidenceThreshold",0.25,"maxDetections",f,"maskFormat",e],y.g,y.b)).cM(B.h8)
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$a5_,w)},
Ml(d,e,f){return this.aEb(d,e,f)},
aEb(d,e,f){var x=0,w=A.l(y.i),v
var $async$Ml=A.m(function(g,h){if(g===1)return A.i(h,w)
for(;;)switch(x){case 0:v=$.bO().ea("/api/public/events/theme-design/swap-colors",A.Q(["imageBase64",e,"masks",f,"edits",d],y.g,y.b)).cM(B.h8)
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$Ml,w)},
Wt(d,e,f,g,h,i,j,k){return this.axC(d,e,f,g,h,i,j,k)},
axC(d,e,f,g,h,i,j,k){var x=0,w=A.l(y.i),v
var $async$Wt=A.m(function(l,m){if(l===1)return A.i(m,w)
for(;;)switch(x){case 0:v=$.bO().ea("/api/public/events/theme-design/theme-search",A.Q(["eventTitle",e,"eventType",f,"formalityLevel",g,"prompt",j,"baseImageUrl",d,"tags",k,"page",h,"perPage",i],y.g,y.b)).cM(B.h8)
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$Wt,w)},
a4i(d){return this.bid(d)},
bid(d){var x=0,w=A.l(y.i),v
var $async$a4i=A.m(function(e,f){if(e===1)return A.i(f,w)
for(;;)switch(x){case 0:v=$.bO().ea("/api/public/events/theme-design/extract-objects",A.Q(["imagesBase64",d,"confidenceThreshold",0.25,"maxDetections",20],y.g,y.b)).cM(B.h8)
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$a4i,w)},
a2v(d){return this.bdf(d)},
bdf(d){var x=0,w=A.l(y.i),v
var $async$a2v=A.m(function(e,f){if(e===1)return A.i(f,w)
for(;;)switch(x){case 0:v=$.bO().ea("/api/public/events/theme-design/analyze-base",A.Q(["baseImageBase64",d],y.g,y.b)).cM(B.h8)
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$a2v,w)},
a2G(d,e){return this.bdB(d,e)},
bdB(d,e){var x=0,w=A.l(y.i),v
var $async$a2G=A.m(function(f,g){if(f===1)return A.i(g,w)
for(;;)switch(x){case 0:v=$.bO().ea("/api/public/events/theme-design/auto-place",A.Q(["freeSpaces",d,"objects",e],y.g,y.b)).cM(B.h8)
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$a2G,w)},
a6N(d,e){return this.bpr(d,e)},
bpr(d,e){var x=0,w=A.l(y.i),v
var $async$a6N=A.m(function(f,g){if(f===1)return A.i(g,w)
for(;;)switch(x){case 0:v=$.bO().ea("/api/public/events/theme-design/render-composite",A.Q(["baseImageBase64",d,"objects",e],y.g,y.b)).cM(B.h8)
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$a6N,w)}}
var z=a.updateTypes([]);(function inheritance(){var x=a.inherit
x(D.aLf,A.W)})()
var y={i:A.a4("R<e,@>"),l:A.a4("R<@,@>"),g:A.a4("e"),b:A.a4("@")};(function constants(){B.h8=new A.bx(18e7)
B.J9=new A.aj(E.IP,null,null,null,null)
B.zc=new A.aj(E.nR,null,null,null,null)
B.Iv=new A.al(58460,"MaterialIcons",!0)
B.C8=new A.a0(1/0,48)
B.CQ=new A.G(!0,F.cL,null,null,null,null,20,C.a5,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null)
B.CU=new A.G(!0,null,null,null,null,null,12,C.ax,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null)
B.a3c=new A.o("Back",null,null,null,null,null,null,null,null,null,null)})();(function lazyInitializers(){var x=a.lazyFinal
x($,"cIc","tR",()=>new D.aLf())})()};
(a=>{a["qgIDfQA46kAuuxPcTadqBkkn594="]=a.current})($__dart_deferred_initializers__);
//# sourceMappingURL=main.dart.js_58.part.js.map
